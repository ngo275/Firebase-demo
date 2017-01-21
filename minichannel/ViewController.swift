//
//  ViewController.swift
//  minichannel
//
//  Created by nagasaka.shogo on 1/18/17.
//  Copyright © 2017 jp.ne.donuts. All rights reserved.
//

import UIKit
import MobileCoreServices
import Firebase
import FirebaseStorage
import FirebaseDatabase
import AVFoundation
import ObjectMapper

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @IBOutlet var movieTableView: UITableView?

    let refreshControl = UIRefreshControl()
    var movies = [MovieInfo]() {
        didSet {
            self.movieTableView?.reloadData()
            self.refreshControl.endRefreshing()
        }
    }
    var playMovie: MovieInfo?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        refreshControl.addTarget(self, action: #selector(reload(_:)), for: .valueChanged)
        let nib = UINib(nibName: "MovieTableViewCell", bundle: nil)
        movieTableView?.register(nib, forCellReuseIdentifier: "MovieCell")
        movieTableView?.rowHeight = UITableViewAutomaticDimension
        movieTableView?.estimatedRowHeight = 340
        movieTableView?.dataSource = self
        movieTableView?.delegate = self
        movieTableView?.refreshControl = refreshControl
        reload(nil)
        navigationController?.navigationBar.barTintColor = #colorLiteral(red: 0.1529197991, green: 0.1529534459, blue: 0.1529176831, alpha: 1)
        navigationItem.titleView = UIImageView(image: UIImage(named: "TitleLogo"))
    }

    func reload(_ sender: Any?) {
        // 動画を取得する処理を追加する
        let ref = FIRDatabase.database().reference()
        let userID = FIRAuth.auth()?.currentUser?.uid
        ref.child("movies").observeSingleEvent(of: .value, with: { (snapshot) in
            // Get user value
            print(snapshot.children)
            let movies = snapshot.children.flatMap { ($0 as? FIRDataSnapshot)?.value as? [String: Any]}.flatMap { MovieInfo(JSON: $0) }
            self.movies = movies.reversed()
            
            DispatchQueue.main.async {
                //self.movieTableView?.reloadData()
                //self.refreshControl.endRefreshing()
            }
            
        }) { (error) in
            print(error.localizedDescription)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func postButtonDidTouch(sender: UIButton) {
        let vc = UIImagePickerController()
        vc.sourceType = .photoLibrary
        vc.mediaTypes = [kUTTypeMovie as String]
        vc.delegate = self
        self.present(vc, animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let url = info[UIImagePickerControllerMediaURL] as? URL {
            // サムネイルを生成する
            let asset = AVURLAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            let time = CMTimeMakeWithSeconds(asset.duration.seconds / 2, 30)
            if let cgImage = try? imageGenerator.copyCGImage(at: time, actualTime: nil), let thumbnmailData = UIImageJPEGRepresentation(UIImage(cgImage: cgImage), 1) {
                
                // 動画をストレージに保存する
                let storage = FIRStorage.storage().reference()
                let name = NSUUID()
                let movieRef = storage.child("movies/\(name).MOV")
                movieRef.putFile(url, metadata: nil) { metadata, error in
                    if (error != nil) {
                        // Uh-oh, an error occurred!
                    } else {
                        // サムネイルを保存する
                        let thumbnailPath = "thumbnails/\(name).jpg"
                        let thumbnailRef = storage.child(thumbnailPath)
                        thumbnailRef.put(thumbnmailData, metadata: nil) { _ in
                            // データベースに動画エントリを追加する
                            if let user = FIRAuth.auth()?.currentUser {
                                let uid = user.uid
                                var movieData = [
                                    "uid": uid,
                                    "movie_path": "movies/\(name).MOV",
                                    "thumbnail_path": "thumbnails/\(name).jpg"
                                ]
                                if let userName = user.displayName {
                                    movieData["user_name"] = userName
                                }
                                let databaseRef = FIRDatabase.database().reference()
                                let moviesRef = databaseRef.child("movies")
                                let key = moviesRef.childByAutoId().key
                                moviesRef.child(key).setValue(movieData)
                            }
                            picker.dismiss(animated: true)
                        }
                    }
                }

            }
        }
    }
}

extension ViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return movies.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MovieCell", for: indexPath) as! MovieTableViewCell
        // セルに動画情報を設定する処理を追加する
        cell.nameLabel?.text = movies[indexPath.item].userName
        
        guard let path = movies[indexPath.item].thumbnailPath else { return cell }
        
        let storageRef = FIRStorage.storage().reference()
        storageRef.child(path).data(withMaxSize: 1 * 1000 * 1000) { (data, error) in
            guard let d = data else { return }
            
            
            DispatchQueue.main.async {
                cell.thumbnailView.image = UIImage(data: d)
//                self.movieTableView?.reloadData()
                //self.refreshControl.endRefreshing()
            }
        }
        return cell
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let movie = movies[indexPath.row]
        playMovie = movie
        let playerViewController = MoviePlayerViewController()
        // 押されたセルの動画を再生する処理を追加する
        guard let path = playMovie?.moviePath else { return }
        let storageRef = FIRStorage.storage().reference()
        storageRef.child(path).downloadURL { url, error in
            //guard let url = URL(string: url ) else { return }
            playerViewController.loadMovie(url!)
            self.navigationController?.pushViewController(playerViewController, animated: true)
        }
       
        //guard let url = URL(string: urlStr) else { return }
        //playerViewController.loadMovie(url)
        //self.navigationController?.pushViewController(playerViewController, animated: true)
    }
}
