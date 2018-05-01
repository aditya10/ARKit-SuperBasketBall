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
    
    var goalCount:Int = 0
    
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
        
        //ADDED: for contact checking
        sceneView.scene.physicsWorld.contactDelegate = self
        sceneView.scene.physicsWorld.timeStep = 1/300
        addBackboard()
        addGoalHoop()
        registerGesture()
        
        
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
        physicsBody.categoryBitMask = BodyType.backboard.rawValue
        
        backboardNode.physicsBody = physicsBody
        
        //add node to scene
        sceneView.scene.rootNode.addChildNode(backboardNode)
    }
    
    func addGoalHoop(){
        //Goal hoop is used to track number of baskets. It is an invisible cylindrical node with physics to check if the ball touches it (and a goal is recorded)
        let hoop = SCNNode(geometry: SCNCylinder(radius: 0.2, height: 0.00000001))
        hoop.position = SCNVector3(0, 0.65, -3.2)
        hoop.geometry?.firstMaterial?.diffuse.contents = UIColor.blue //update to UIColor.clear later
        let hoopBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: hoop, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))
        hoopBody.categoryBitMask = BodyType.hoop.rawValue
        hoopBody.collisionBitMask = 0
        hoopBody.contactTestBitMask = BodyType.ball.rawValue
    
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
//        physicsBody.categoryBitMask = BodyType.ball.rawValue
//        physicsBody.collisionBitMask = 1
        physicsBody.contactTestBitMask = BodyType.hoop.rawValue
        
        ballNode.physicsBody = physicsBody
        
        let forceVector:Float = 8
        let upwardPush:Float = 3
        ballNode.physicsBody?.applyForce(SCNVector3(cameraOrientation.x*forceVector, cameraOrientation.y*forceVector+upwardPush, cameraOrientation.z*forceVector), asImpulse: true)
        
        sceneView.scene.rootNode.addChildNode(ballNode)
        
    }
    
    
    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
        //if((contact.nodeA.physicsBody?.categoryBitMask == BodyType.hoop.rawValue && contact.nodeB.physicsBody?.categoryBitMask == BodyType.ball.rawValue) || (contact.nodeB.physicsBody?.categoryBitMask == BodyType.hoop.rawValue && contact.nodeA.physicsBody?.categoryBitMask == BodyType.ball.rawValue)){
                goalCount = goalCount+1
                print(goalCount)
       // }
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
