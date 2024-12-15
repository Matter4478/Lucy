//
//  ContentView.swift
//  Lucy
//
//  Created by M. De Vries on 15/12/2024.
//

import SwiftUI
import MapKit
import CoreLocation
import AVFoundation
import UserNotifications

struct ContentView: View {
    @EnvironmentObject private var appDelegate: LucyAppDelegate
    @ObservedObject var VModel: ViewModel = viewModel
    var body: some View {
        NavigationView(){
            VStack {
//                if #available(iOS 17.0, *) {
//                    Map()
//                        .clipShape(.rect(cornerSize: .init(width: 10, height: 10), style: .continuous))
//                } else {
                    // Fallback on earlier versions
                    MapUIViewRepresentable()
                        .clipShape(.rect(cornerSize: .init(width: 10, height: 10), style: .continuous))
//                }
                Button(action: {
                    if VModel.FlashLightIntensity == 0{
                        VModel.FlashLightIntensity = 1
                        VModel.setTorch(intensity: 1)
                        VModel.ShowAlert = true
                    } else {
                        VModel.FlashLightIntensity = 0
                        VModel.setTorch(intensity: 0)
                    }
                    
                }){
                    Text("Alarm")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.white)
                }.background{
                    Circle()
                        .fill(Color.red)
                        .frame(width: 200, height: 200)
                }
            }
            .toolbar(content: {
                ToolbarItem(){
                    Button(action: {VModel.ViewSettingsPane.toggle()}){
                        Image(systemName: "gear")
                    }
                }
            })
            .navigationTitle(Text("Lucy"))
            .padding()
            .sheet(isPresented: $VModel.ViewSettingsPane) {
                SettingsView(VModel: VModel)
            }
            .onAppear {
                VModel.setHomeLocation()
                VModel.LManager.startUpdatingLocation()
                Task{
                    do {
                        try await center.requestAuthorization(options: [.criticalAlert, .alert, .sound, .providesAppNotificationSettings])
                    } catch {
                        print(error)
                    }
                }
            }
            .alert("Alarm mode engaged", isPresented: $VModel.ShowAlert) {
                Button("Disengage", role: .cancel, action: {
                    VModel.ShowAlert = false
                    VModel.FlashLightIntensity = 0
                    VModel.setTorch(intensity: 0)
                })
            }
        }
    }
}

struct MapUIViewRepresentable: UIViewRepresentable{
    func makeUIView(context: Context) -> some UIView {
        let map = MKMapView()
        map.showsUserLocation = true
        map.showsScale = true
        map.showsCompass = true
        map.userTrackingMode = .followWithHeading
        return map
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        
    }
}



struct SettingsView: View{
    @Environment(\.presentationMode) var presentationValue
    @ObservedObject var VModel: ViewModel
    var body: some View{
        NavigationStack{
            List{
                Section(header: Text("Torch Intensity")) {
                    Slider(value: $VModel.FlashLightIntensity, in: 0...1) { change in
                        VModel.setTorch(intensity: VModel.FlashLightIntensity)
                    }
                }
                
                Section(header: Text("Set Current Location")){
                    Slider(value: $VModel.TargetDistance, in: 0...500){ change in
                    }
                    Button("Set Current Location as Home") {
                        VModel.setHomeLocation()
                        VModel.sendNotification(title: "Button", subtitle: "", body: "")
                    }
                }
            }
            .navigationTitle(Text("Settings"))
            .toolbar(content: {
                ToolbarItem{
                    Button(action:{self.presentationValue.wrappedValue.dismiss()}){
                        Image(systemName: "x.circle")
                    }
                }
            })
        }
    }
}

#Preview {
    ContentView()
}

var viewModel = ViewModel()

class ViewModel: ObservableObject{
    var LManager: LocationManager{
        let manager = LocationManager(VModel: self)
        return manager
    }
    
    
    func getAuthorization() async{
        Task{
            do {
                try await center.requestAuthorization(options: [.criticalAlert, .alert, .sound, .providesAppNotificationSettings])
            } catch {
                print(error)
            }
        }
    }
    
    
    @Published var ViewSettingsPane: Bool = false
    @Published var ShowAlert: Bool = false
    @Published var FlashLightIntensity: Float = 0.0
    @Published var HomeCoordinates: CLLocation?
    @Published var TargetDistance: CLLocationDistance = 100
    @Published var TargetRegion: CLRegion?
    
    
    func setTorch(intensity: Float){
        guard let device = AVCaptureDevice.default(for: .video) else {
            return
        }
        
        if device.hasTorch{
            do {
                try device.lockForConfiguration()
                if intensity == 0{
                    device.torchMode = .off
                } else {
                    device.torchMode = .on
                    try device.setTorchModeOn(level: intensity)
                }
            } catch {
                print(error)
            }
        }
    }
    
    func setHomeLocation(){
        LManager.requestAlwaysAuthorization()
        LManager.startUpdatingLocation()
        LManager.requestingLocation = true
    }
    
    func sendNotification(title: String, subtitle: String, body: String){
        let identifier = "LucyAlertNotification"
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
        print("Scheduled request")
    }
    
    
}

//class NotificationManager: NSObject, UNUserNotificationCenterDelegate{
//    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
//        completionHandler(.banner)
//    }
//}

class LocationManager: CLLocationManager, CLLocationManagerDelegate{
    required init(VModel: ViewModel) {
        self.parent = VModel
        super.init()
        self.delegate = self
        self.requestAlwaysAuthorization()
        self.showsBackgroundLocationIndicator = true
    }
    
    var requestingLocation: Bool = false
    var parent: ViewModel
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus != .authorizedAlways{
            manager.requestAlwaysAuthorization()
        }
        
        print("locationManager did change authorization: \(manager.authorizationStatus)")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("location did update")
        if self.requestingLocation{
            guard let location = locations.first else {
                return
            }
            if parent.TargetRegion != nil{
                self.stopMonitoring(for: parent.TargetRegion!)
            }
            parent.HomeCoordinates = location
            self.requestingLocation = false
            let region = CLCircularRegion(center: location.coordinate, radius: parent.TargetDistance / 2, identifier: "")
            self.parent.TargetRegion = region
            self.startMonitoring(for: region)
            parent.sendNotification(title: "start monitoring location", subtitle: "home location reset", body: "target distance: \(parent.TargetDistance)")
            print("homelocation reset")
            self.stopUpdatingLocation()
        } else {
            if let location = locations.first, let home = parent.HomeCoordinates{
                if location.distance(from: home) >= parent.TargetDistance {
                    parent.sendNotification(title: "Je bent ver weg, ben je okay?", subtitle: "", body: "Lucy heeft gezien dat je te ver weg bent, is dat de bedoeling?")
                }
                parent.ShowAlert = true
                parent.FlashLightIntensity = 1
                parent.setTorch(intensity: 1)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        self.startUpdatingLocation()
        print("did exit region: \(region)")
        parent.sendNotification(title: "exitregion", subtitle: "", body: "\(region)")

    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        self.stopUpdatingLocation()
        print("did enter region: \(region)")
        parent.sendNotification(title: "", subtitle: "enterregion", body: "\(region)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        print(error)
        parent.sendNotification(title: "Error", subtitle: "", body: "\(error)")
    }
}
