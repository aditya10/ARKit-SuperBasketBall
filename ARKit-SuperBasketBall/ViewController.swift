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

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
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
        
        addBackboard()
        addGoalHoop()
        registerGesture()
        
        
    }
    
    func addBackboard(){
        guard let backboardScn = SCNScene(named: "art.scnassets/hoop.scn") else {
            return
        }
        guard let backboardNode = backboardScn.rootNode.childNode(withName: "backboard", recursively: false) else {
            return
        }
        backboardNode.position = SCNVector3(x: 0, y: 0.5, z: -4)
        
        let physicsShape = SCNPhysicsShape(node: backboardNode, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron])
        let physicsBody = SCNPhysicsBody(type: .static, shape: physicsShape)
        
        backboardNode.physicsBody = physicsBody
        
        sceneView.scene.rootNode.addChildNode(backboardNode)
    }
    
    func addGoalHoop(){
        //add invisible hoop to
        let hoop = SCNNode(geometry: SCNCylinder(radius: 0.3, height: 0.05))
        hoop.position = SCNVector3(0, 0.68, -3.4)
        hoop.geometry?.firstMaterial?.diffuse.contents = UIColor.blue //update to UIColor.clear later
        let hoopBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: hoop, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))
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
        
        ballNode.physicsBody = physicsBody
        
        let forceVector:Float = 8
        let upwardPush:Float = 3
        ballNode.physicsBody?.applyForce(SCNVector3(cameraOrientation.x*forceVector, cameraOrientation.y*forceVector+upwardPush, cameraOrientation.z*forceVector), asImpulse: true)
        
        sceneView.scene.rootNode.addChildNode(ballNode)
        
    }
    
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        print("contact happened")
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
