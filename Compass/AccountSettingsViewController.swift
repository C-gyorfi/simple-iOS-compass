//
//  AccountSettingsViewController.swift
//  Compass
//
//  Created by Csabi on 24/10/2018.
//  Copyright © 2018 Csabi. All rights reserved.
//

import UIKit
import Parse

class AccountSettingsViewController: UIViewController {

    let deleteAccountButton = UIButton()
    let par = PServer()
    let userData = UserData()
    var activityIndicator = UIActivityIndicatorView()
    let nameLabel = UILabel()
    let nameTextField = UITextField()
    let aboutLabel = UILabel()
    var avatarImage = UIImageView()
    let userInforTextField = UITextView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createUI()
        setUpHandlers()
        
        guard let userName = UserDefaults.standard.string(forKey: "UserName") else {
            print("ERROR current user doesnt exist")
            self.navigationController?.popViewController(animated: true)
            return
        }
        self.userData.name = userName
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func createUI(){
        
        navigationController?.navigationBar.barTintColor = UIColor.black
        self.view.backgroundColor = UIColor.darkGray
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.green]
        navigationItem.title = "Account Settings"
        
        let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveUserDetails))
        self.navigationItem.rightBarButtonItem  = saveButton
        
        deleteAccountButton.setTitle("Delete Account", for: .normal)
        deleteAccountButton.setTitleColor(UIColor.red, for: .normal)
        
        self.avatarImage = UIImageView(image: UIImage(named: "avatar.png"))
        nameLabel.text = "Name:"
        nameLabel.textColor = UIColor.white
        nameTextField.backgroundColor = UIColor.lightGray
        nameTextField.placeholder = "choose a nickname..."
        
        userInforTextField.backgroundColor = UIColor.lightGray
        userInforTextField.text = "Welcome to my profile..."
        aboutLabel.text = "About:"
        aboutLabel.textColor = UIColor.white
        
        let nameRowsStackView = UIStackView(arrangedSubviews: [nameLabel, nameTextField])
        nameRowsStackView.axis = .vertical
        nameRowsStackView.spacing = 10
        
        let topStackView = UIStackView(arrangedSubviews: [avatarImage, nameRowsStackView])
        topStackView.axis = .horizontal
        topStackView.spacing = 10
        
        let stackView = UIStackView(arrangedSubviews: [topStackView, aboutLabel, userInforTextField, deleteAccountButton])
        stackView.axis = .vertical
        stackView.spacing = 20
        
        self.view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
//        stackView.alignment = .leading
        NSLayoutConstraint.activate([stackView.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.size.width-25),
                                     stackView.centerXAnchor.constraint(lessThanOrEqualTo: self.view.centerXAnchor),
                                     stackView.centerYAnchor.constraint(lessThanOrEqualTo: self.view.centerYAnchor)])
        
        NSLayoutConstraint.activate([avatarImage.heightAnchor.constraint(equalToConstant: 60),
                                     avatarImage.widthAnchor.constraint(equalToConstant: 60)])
        
        NSLayoutConstraint.activate([userInforTextField.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.size.width),
                                     userInforTextField.heightAnchor.constraint(equalToConstant: 200)])
    }
    
    private func setUpHandlers() {
        deleteAccountButton.addTarget(self, action: #selector(deleteAccount), for: .touchUpInside)
    }
    
    @objc private func deleteAccount() {
        
        
        let alert = UIAlertController(title: "Account will be deleted", message: "Do you wish to continue?", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction.init(title: "Yes", style: .default, handler: { (action) in
            
            self.activityIndicator = UIActivityIndicatorView(frame: CGRect.zero)
            self.activityIndicator.center = self.view.center
            self.activityIndicator.hidesWhenStopped = true
            self.activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
            self.view.addSubview(self.activityIndicator)
            self.activityIndicator.startAnimating()
            UIApplication.shared.beginIgnoringInteractionEvents()
            
            let query = PFQuery(className: "Locations")
     
            query.whereKey("UserName", equalTo: self.userData.name)
                query.findObjectsInBackground { (objects, error) in
                    if let error = error {
                        print(error)
                    } else if let object = objects?.first {
                        
                        if let obj = object as? PFObject {
                            print("Deleting: \(obj)")
                            obj.deleteInBackground(block: { (success, error) in
                                if error != nil {
                                    print(error ?? "error while deleting")
                                } else {
                                    PFUser.current()?.deleteInBackground(block: { (success, error) in
                                        guard error == nil else {
                                            var displayErrorMessage = "Error while deleting account, please try again"
                                            let error = error as NSError?
                                            if let errorMessage = error?.userInfo["error"] as? String {
                                                displayErrorMessage = errorMessage
                                            }
                                            self.createAlert(title: "Error:", message: displayErrorMessage)
                                            return
                                        }
                                        if success {
                                            PFUser.logOut()
                                            UserDefaults.standard.removeObject(forKey: "locationObjectId")
                                            UserDefaults.standard.removeObject(forKey: "userName")
                                            self.activityIndicator.stopAnimating()
                                            UIApplication.shared.endIgnoringInteractionEvents()
                                            self.navigationController?.popToRootViewController(animated: true)
                                        }
                                    })
                                    print("Object deleted")}
                            })
                        }
                    }
                }
            self.dismiss(animated: true, completion: nil)
        }))
        
        alert.addAction(UIAlertAction.init(title: "No", style: .default, handler: { (action) in
            self.dismiss(animated: true, completion: nil)
        }))
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func createAlert(title: String, message: String) {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction.init(title: "OK", style: .default, handler: { (action) in
            self.dismiss(animated: true, completion: nil)
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc func saveUserDetails(){
        print("save user details function not yet implemented")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        userInforTextField.resignFirstResponder()
    }
    
}
