//
//  ViewController.swift
//  ARKit-SuperBasketBall
//
//  Created by Aditya Chinchure on 2018-04-28.
//  Copyright © 2018 Aditya Chinchure. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

enum BodyType:Int{
    case hoop = 1
    case ball = 2
    case backboard = 4
}

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var basketsLabel: UILabel!
    @IBOutlet weak var highScoreLabel: UILabel!
    
    var goalCount:Int = 0
    var highScore:Int!
    var goal:Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        //Initial setup for user defaults - stores high score for each user permanenetly.
        if let hs = UserDefaults.standard.object(forKey: "highScore") as? Int {
            highScore = hs
            highScoreLabel.text = String(highScore)
        } else {
            UserDefaults.standard.set(0, forKey: "highScore")
            highScore = UserDefaults.standard.object(forKey: "highScore") as? Int
            highScoreLabel.text = String(highScore)
        }
        
        //ADDED: for contact checking
        sceneView.scene.physicsWorld.contactDelegate = self
        sceneView.scene.physicsWorld.timeStep = 1/300
        addBackboard()
        addGoalHoop()
        registerGesture()
        
        
    }
    
    func updateHighScore(){
        //updates high score when goalCount>highScore
        UserDefaults.standard.set(goalCount, forKey: "highScore")
        if let hs = UserDefaults.standard.object(forKey: "highScore") as? Int {
            highScore = hs
        }
        highScoreLabel.text = String(highScore)
    }
    
    func addBackboard(){
        //import backboard asset
        guard let backboardScn = SCNScene(named: "art.scnassets/hoop.scn") else {
            return
        }
        //The node here is just the backboard, minus the net (see hoop.scn asset)
        guard let backboardNode = backboardScn.rootNode.childNode(withName: "backboard", recursively: false) else {
            return
        }
        //location of backboard in 3D space
        backboardNode.position = SCNVector3(x: 0, y: 0.5, z: -4)
        
        //backboard physics
        //- concavePolyhedron improves the physics body shape around the node. Without it, the ball will not fall through the hoop. It is usually disabled because it takes more processing power.
        //- .static so that it is not affected by gravity and is fixed to that location.
        let physicsShape = SCNPhysicsShape(node: backboardNode, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron])
        let physicsBody = SCNPhysicsBody(type: .static, shape: physicsShape)
        
        // associate it to it's BodyType (enum value)
        physicsBody.categoryBitMask = BodyType.backboard.rawValue
        
        backboardNode.physicsBody = physicsBody
        
        //add node to scene
        sceneView.scene.rootNode.addChildNode(backboardNode)
    }
    
    func addGoalHoop(){
        //Goal hoop is used to track number of baskets. It is an invisible cylindrical node with physics to check if the ball touches it (and a goal is recorded)
        guard let hoopScn = SCNScene(named: "art.scnassets/hoop.scn") else {
            return
        }
        //The node here is just the goalHoop, minus the net (see hoop.scn asset)
        guard let hoop = hoopScn.rootNode.childNode(withName: "plane", recursively: false) else {
            return
        }
        hoop.position = SCNVector3(0, 0.63, -3.6)
        hoop.geometry?.firstMaterial?.diffuse.contents = UIColor.clear //Use UIColor.blue to see and debug
        let hoopBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: hoop, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))
        
        hoopBody.categoryBitMask = BodyType.hoop.rawValue
        hoopBody.collisionBitMask = 0 //This value is set to 0 so that any collisions with it do not lead to restitution (bouncing) and the ball can travel through this body
        hoopBody.contactTestBitMask = BodyType.ball.rawValue //used to check collisions - also see ball below
    
        hoop.physicsBody = hoopBody
        sceneView.scene.rootNode.addChildNode(hoop)
    }
    
    func registerGesture(){
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        sceneView.addGestureRecognizer(tap)
    }
    
    @objc func handleTap(gr: UIGestureRecognizer){
       //Access Scene View and its center
        guard let sceneView = gr.view as? ARSCNView else {return}
        guard let centerPoint = sceneView.pointOfView else {return}
        
        //transform matrix
        //Orientation, location of camera
        let cameraTransform = centerPoint.transform
        let cameraLocation = SCNVector3(x: cameraTransform.m41, y: cameraTransform.m42, z: cameraTransform.m43)
        let cameraOrientation = SCNVector3(x: -cameraTransform.m31, y: -cameraTransform.m32, z: -cameraTransform.m33)
        
        let cameraPos = SCNVector3Make(cameraLocation.x+cameraOrientation.x, cameraLocation.y+cameraOrientation.y, cameraLocation.z+cameraOrientation.z)
        
        let ball = SCNSphere(radius: 0.15)
        let material = SCNMaterial()
        material.diffuse.contents = UIImage(named: "basketballSkin.png")
        ball.materials = [material]
        
        let ballNode = SCNNode(geometry: ball)
        ballNode.position = cameraPos
        
        let physicsShape = SCNPhysicsShape(node: ballNode, options: nil)
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: physicsShape)
        //test contact with hoop, together it will generate a trigger for collision detection
        physicsBody.contactTestBitMask = BodyType.hoop.rawValue
        
        ballNode.physicsBody = physicsBody
        
        let forceVector:Float = 8
        let upwardPush:Float = 3
        ballNode.physicsBody?.applyForce(SCNVector3(cameraOrientation.x*forceVector, cameraOrientation.y*forceVector+upwardPush, cameraOrientation.z*forceVector), asImpulse: true)
        
        sceneView.scene.rootNode.addChildNode(ballNode)
        
        //After 3 seconds, check if the ball has achieved a goal (i.e. collision is set to true).
        // NOTE/WARNING: This is not an ideal implementation because if two consecutive balls are launched and only one scores a basket, it is possible (because of the time gap) that two baskets are counted.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: {
            self.checkGoals()
        })
        
    }
    
    func checkGoals(){
        //Checks if a point is scored. See warning at the function call -- this is not a good implementation of counting the score
        if(goal){
            goalCount = goalCount+1
            basketsLabel.text = String(goalCount)
            goal=false
            if(goalCount > highScore){
                updateHighScore()
            }
        }
    }
    
    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
        //check collision between ball and goalHoop. This resuts in setting the goal parameter to true.
        goal = true
    }
    

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
