//
//  LocationController.swift
//  Russia TV
//
//  Created by Сергей Сейтов on 19.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

class Pin : NSObject, MKAnnotation {
    
    var pinCoord:CLLocationCoordinate2D?
    
    init(_ coord:CLLocationCoordinate2D) {
        super.init()
        pinCoord = coord
    }
    
    var coordinate: CLLocationCoordinate2D {
        return pinCoord!
    }
    
    var title: String? {
        return ""
    }
    
    var subtitle: String? {
        return ""
    }
}

class LocationController: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var map: MKMapView!
    
    var userLocation:CLLocationCoordinate2D?
    var locationDate:Date?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackButton()
        setupTitle("\(Model.shared.textDateFormatter.string(from: locationDate!))")
        
        let span = MKCoordinateSpanMake(0.1, 0.1)
        let region = MKCoordinateRegionMake(userLocation!, span)
        map.setRegion(region, animated: true)
        
        let pin = Pin(userLocation!)
        map.addAnnotation(pin)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let view = MKAnnotationView(annotation: annotation, reuseIdentifier: "location")
        view.image = UIImage(named: "position")
        return view
    }
}
