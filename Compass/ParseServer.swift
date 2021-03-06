//
//  ParseServer.swift
//  Compass
//
//  Created by Csabi on 12/09/2018.
//  Copyright © 2018 Csabi. All rights reserved.
//

import Foundation
import Parse

class PServer {
    
    enum MyError: Error {
        case objectNotFound
        case signUpError
        case savingError
        case logInError
        case errorWhileUnwappingData
    }
    
    func initParse(appID: String, clKey: String, serverAddress: String) {

        Parse.enableLocalDatastore()
        //find parse
        let parseConfig = ParseClientConfiguration(block:  {(ParseMutableClientConfiguration) -> Void in
            ParseMutableClientConfiguration.applicationId = appID
            ParseMutableClientConfiguration.clientKey = clKey
            ParseMutableClientConfiguration.server = serverAddress
        })
        
        Parse.initialize(with: parseConfig)
       // PFUser.enableAutomaticUser()
        let defaultACL = PFACL()
        defaultACL.hasPublicReadAccess = true
        PFACL.setDefault(defaultACL, withAccessForCurrentUser: true)
    }
    
    func logIn(userName: String, pass: String, completition: @escaping (PFUser?, Error?) -> Void) {
        PFUser.logInWithUsername(inBackground: userName, password: pass) { (user, error) in
            guard error == nil else {
                completition (nil, error)
                return
            }
            if user != nil {
                completition(user, nil)
                return
            }
            completition(nil, MyError.logInError)
        }
    }
    
    func SignUp(userName: String, pass: String, completition: @escaping (Bool, Error?) -> Void) {
        let user = PFUser()
        user.username = userName
        user.email = userName
        user.password = pass
        user.signUpInBackground { (success, error) in
            guard error == nil else {
                completition(false, error)
                return
            }
            if success {
                completition(true, nil)
                return
            }
            completition(false, MyError.signUpError)
        }
    }
    
    func deleteUser(completition: @escaping (Bool, Error?) -> Void) {
        let query = PFQuery(className: "Locations")
        query.whereKey("UserName", equalTo: PFUser.current()?.username)
        query.findObjectsInBackground { (objects, error) in
            guard error == nil else {
                completition(false, error)
                return
            }
            
            guard let object = objects?.first else {
                completition(false, MyError.objectNotFound)
                return
            }
            
            object.deleteInBackground(block: { (success, error) in
                guard error == nil else {
                    completition(false, error)
                    return
                }
                
                PFUser.current()?.deleteInBackground(block: { (success, error) in
                    guard error == nil else {
                        completition(false, error)
                        return
                    }
                    if success {
                        PFUser.logOut()
                        UserDefaults.standard.removeObject(forKey: "locationObjectId")
                        UserDefaults.standard.removeObject(forKey: "userName")
                        completition(true, nil)
                        return
                    }
                })
            })
        }
    }
    
    func saveNewLocation(classN: String, uData: UserData) {
        let saveObject = PFObject(className: classN)
        saveObject["UserName"] = PFUser.current()?.username
        saveObject["Location"] = PFGeoPoint(location: uData.location)
        //object ID is being returned before updated because its saving in BG
        saveObject.saveInBackground { (success, error) -> Void in
            if error != nil { print(error ?? "error while saving user location")
            }
            else {
                UserDefaults.standard.set(saveObject.objectId, forKey: "locationObjectId")
                print("New location object saved to server")
            }
        }
    }

    func getObjectId(classN: String, uData: UserData) {
        let quiery = PFQuery(className: classN)
        quiery.whereKey("UserName", equalTo: PFUser.current()?.username)
        
        quiery.findObjectsInBackground { (objects, error) in
            guard error == nil else {
                return
            }
            guard let objects = objects else {
                print("objects not found")
                return
            }
                if let objectID = objects.first?.objectId {
                    print("fetched location id for curr user, id: \(objectID)")
                    UserDefaults.standard.set(objectID, forKey: "locationObjectId")
                } else {
                    self.saveNewLocation(classN: classN, uData: uData)
            }
        }
    }
    
    public func updateUserLocation(classN: String, id: String, location: CLLocation?) {
        let quiery = PFQuery(className: classN)
        quiery.getObjectInBackground(withId: id, block: { (object, error) in
            guard error == nil else {
                print(error ?? "Failed to fetch data")
                return
            }
                guard let newUserData = object else {
                    print("object doesnt exist")
                    return
                }
            newUserData["Location"] = PFGeoPoint(location: location)
            newUserData["UserName"] = PFUser.current()?.username
            newUserData.saveInBackground(block: { (sucess, error) in
                guard error == nil else {
                    print(error ?? "Failed to update data")
                    return
                }
            })
        })
    }
    
    func fetchUserList(completition: @escaping ([String]?, Error?) -> Void) {
        let query = PFUser.query()
        query?.findObjectsInBackground(block: { (objects, error) in
            var result = [String]()
            guard error == nil else {
                completition(nil, error)
                return
            }
            if let users = objects {
                for object in users {
                    if let user = object as? PFUser {
                        if user.username != PFUser.current()?.username {
                            guard let userName = user.username else {return}
                            result.append(userName)
                        }
                    }
                }
                completition(result, nil)
                return
            }
            completition(nil, MyError.errorWhileUnwappingData)
        })
    }
    
    func fetchUserData(userName: String, completion: @escaping (UserData?, Error?) -> Void) {
        let result = UserData()
        result.name = userName
        let query = PFUser.query()
        query?.findObjectsInBackground(block: { (objects, error) in
            guard error == nil else {
                print(error ?? "error while fetching user names")
                completion(nil, error)
                return
            }
            guard let users = objects else {
                completion(nil, nil)
                return
            }
            for object in users {
                guard let user = object as? PFUser else {
                    completion(nil, nil)
                    return
                }
                if user.username == userName {
                    if let userInfo = user.value(forKey: "userInfo") as? String {
                        result.userInfo = userInfo}
                    if let avatarPic = user.value(forKey: "avatar") as? PFFile {
                        avatarPic.getDataInBackground { (imageData, error) in
                            if error == nil {
                                let image = UIImage(data:imageData!)
                                result.avatar = image!
                                completion(result, nil)
                                return
                            } else {
                                print(error ?? "error while fetching image")
                            }
                        }
                    }
                }
            }
            //this will return an error even on completition
            //completion(nil, MyError.errorWhileUnwappingData)
        })
    }
    
    func saveUserData(userData: UserData, completion: @escaping (Bool, Error?) -> Void){
        let user = PFUser.current()
        let imageData = UIImageJPEGRepresentation(userData.avatar, 0.1)
        let imageFile = PFFile(name: "avatar.png", data: imageData!)
        user!["avatar"] = imageFile
        user!.username = userData.name
        user!["userInfo"] = userData.userInfo
        user?.saveInBackground(block: { (success, error) in
            guard error == nil else {
                completion(false, error)
                return
            }
            if success {
                if let id = UserDefaults.standard.string(forKey: "locationObjectId") {
                    self.updateUserLocation(classN: "Locations", id: id, location: nil)
                }
                completion(true, nil)
                return
            }
            completion(false, MyError.savingError)
        })
    }
    
    func findUsersLocation(userName: String) -> CLLocation? {
        
        let query = PFQuery(className: "Locations")
            query.whereKey("UserName", equalTo: userName)
        do {
            let objects: [PFObject] = try query.findObjects()
            if let object = objects.first {
            if let location = object["Location"] as? PFGeoPoint {
                return CLLocation(latitude: location.latitude, longitude: location.longitude)
                }
            }
        } catch {
            print("error while fetching location: \(error)")
        }
       return nil
    }
    
    func saveNewChat(user1: String, user2: String, chatMessage: [String]) {
        //temp solution should give access to user1 and user2
        let acl = PFACL()
        acl.hasPublicWriteAccess = true
        acl.hasPublicReadAccess = true
        let parseObject = PFObject(className: "ChatMessages")
        parseObject["Participants"] = [user1, user2]
        parseObject["Messages"] = [chatMessage]
        parseObject.acl = acl
        parseObject.saveInBackground { (success, error) in
            guard error == nil else {
                return
            }
            if success {
                print("New chat messages object saved")
            }
        }
    }
    
    func saveChatMessage(user1: String, user2: String, chatMessage: [String], completion: @escaping (Bool, Error?) -> Void) {
        
        let query = PFQuery(className: "ChatMessages")
        query.whereKey("Participants", containsAllObjectsIn: [user1, user2])
        query.findObjectsInBackground { (ChatObjects, error) in
            guard error == nil else {
                return
            }
            
            guard let UpdatedChatObjects = ChatObjects?.first else {
                print("Chat objects cannot be found")
                self.saveNewChat(user1: user1, user2: user2, chatMessage: chatMessage)
                return
            }
            
            if var messages = UpdatedChatObjects["Messages"] as? [[String]] {
                print("yaaay query works")
                messages.append(chatMessage)
                UpdatedChatObjects["Messages"] = messages
                
                UpdatedChatObjects.saveInBackground(block: { (success, error) in
                    guard error == nil else {
                        print("failed to save chat")
                        completion(false, error)
                        return
                    }
                    if success {
                        print("object been updated")
                        completion(true, nil)
                        return
                    }
                })
            }
        }
    }
    
    func fetchChat(user1: String, user2: String, completion: @escaping ([ChatMessage]?, Error?) -> Void) {
        var result = [ChatMessage]()
        
        let query = PFQuery(className: "ChatMessages")
        query.whereKey("Participants", containsAllObjectsIn: [user1, user2])
        query.getFirstObjectInBackground { (ChatObject, error) in
            guard error == nil else {
                completion(nil, error)
                return
            }
            guard let ChatObject = ChatObject else {
                completion(nil, MyError.errorWhileUnwappingData)
                return
            }
            
            if let messages = ChatObject["Messages"] as? [[String]] {
                for message in messages {
                    let chatMessage = ChatMessage(sender: message[0], text: message[1], date: message[2])
                    result.append(chatMessage)
                }
                completion(result, nil)
                return
            }
        }
    }
}

class UserData {
    var name = PFUser.current()?.username
    var password = PFUser.current()?.password
    var userInfo = String()
    var avatar = UIImage()
    var location = CLLocation()
    var objectID = String()
}

struct ServerCredentials: Decodable {
    let appID: String
    let clKey: String
    let serverAddress: String
    
    //initialiser could be reduced since its a Decodable object
    init(json: [String: Any]) {
        appID = json["appID"] as? String ?? ""
        clKey = json["clKey"] as? String ?? ""
        serverAddress = json["serverAddress"] as? String ?? ""
    }
}

struct ChatMessage {
    let sender: String
    let text: String
    let date: String
}
