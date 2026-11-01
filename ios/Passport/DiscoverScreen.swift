import SwiftUI
import MapKit
import CoreLocation

@MainActor final class RestaurantLocation:NSObject,ObservableObject,CLLocationManagerDelegate {
    @Published var point:SearchPoint?
    @Published var message=""
    @Published var requesting=false
    private let manager=CLLocationManager()
    override init(){super.init();manager.delegate=self;manager.desiredAccuracy=kCLLocationAccuracyKilometer}
    func request(){message="";requesting=true;switch manager.authorizationStatus{case .notDetermined:manager.requestWhenInUseAuthorization();case .authorizedWhenInUse,.authorizedAlways:manager.requestLocation();default:requesting=false;message="Location access unavailable. Search a suburb or city instead."}}
    func locationManagerDidChangeAuthorization(_ manager:CLLocationManager){guard requesting else{return};switch manager.authorizationStatus{case .authorizedWhenInUse,.authorizedAlways:manager.requestLocation();case .denied,.restricted:requesting=false;message="Location permission denied. Enter a suburb or city instead.";default:break}}
    func locationManager(_ manager:CLLocationManager,didUpdateLocations locations:[CLLocation]){requesting=false;guard let c=locations.last?.coordinate else{return};point=SearchPoint(lat:c.latitude,lon:c.longitude)}
    func locationManager(_ manager:CLLocationManager,didFailWithError error:Error){requesting=false;message="Location unavailable. Enter a suburb or city instead."}
}
struct NearbyRestaurant:Identifiable {let id:String;let item:MKMapItem}
struct DiscoverScreen:View {
    @StateObject private var location=RestaurantLocation()
    @State private var area=""
    @State private var point:SearchPoint?
    @State private var radius=3000
    @State private var nearby:[NearbyRestaurant]=[]
    @State private var popular:[PopularPlace]=[]
    @State private var busy=false
    @State private var error=""
    @State private var checked=""
    @State private var hasNearby=false
    @State private var hasPopular=false
    @State private var selection:Entry?
    @State private var providerLabel=""
    var body:some View{List{
        FoodBanner(title:"Your next\nfavourite table.",subtitle:"NEARBY DISCOVERIES",asset:"FoodTable").listRowInsets(EdgeInsets()).listRowSeparator(.hidden)
        Section("Choose a search area"){
            TextField("Suburb or city, e.g. Adelaide",text:$area)
            Button("Search this area"){Task{await resolveArea()}}.disabled(busy || area.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
            Button(location.requesting ? "Finding your area…":"Use my location"){location.request()}.disabled(busy || location.requesting)
            Picker("Radius",selection:$radius){Text("1 km").tag(1000);Text("3 km").tag(3000);Text("5 km").tag(5000);Text("10 km").tag(10000)}
            Text(location.message).font(.caption)
            if let point{Text(String(format:"Selected area: %.3f, %.3f",point.lat,point.lon)).font(.caption);Button("Find nearby restaurants · Apple Maps"){Task{await searchNearby(point)}}.disabled(busy)
                Button("Find popular nearby · Google Maps"){Task{await searchPopular(point)}}.disabled(busy)}
            if busy{ProgressView("Finding restaurants…")}
            Text(error).font(.caption)
        }
        Section("Trending & nearby"){
            Text("Looking for somewhere people love? Try popular nearby places. A rising or real-time trending feed is not connected: Google popularity is a discovery signal, not evidence of recent growth. Apple results are nearby matches and carry no trend score.").font(.caption)
            Text("Suggestions do not use your private visit history. Ratings are community opinions, not guarantees. Confirm hours, dietary needs and availability with the restaurant.").font(.caption)
        }
        if hasPopular{Section("Popular nearby · Google Maps"){
            if popular.isEmpty{Text("No popular places returned for this area. Try another radius; coverage may be incomplete.")}
            ForEach(popular){place in PopularCard(place:place){var r=Entry.new(visit:false);r.fields["googlePlaceID"] = .string(place.id);selection=r;providerLabel="Google"}}
            Text("Google Maps · Checked "+checked).font(.system(size:14,weight:.medium))
            Text("Popularity ordering supplied by Google. Results are transient, not a verified list of rising restaurants. Save only your own name and notes; the Google place ID is retained for reference.").font(.caption)
        }}
        if hasNearby{Section("Nearby matches · Apple Maps"){
            if nearby.isEmpty{Text("No restaurant matches found. Try a different area or radius.")}
            ForEach(nearby){r in VStack(alignment:.leading,spacing:8){Text(r.item.name ?? "Restaurant").font(.headline);Text(r.item.placemark.title ?? "").font(.caption)
                HStack{Button("Open in Maps"){r.item.openInMaps()}.buttonStyle(.bordered);Button("Save for later"){var entry=Entry.new(visit:false);entry["name"]=r.item.name ?? "";entry["suburb"]=r.item.placemark.subLocality ?? "";entry["city"]=r.item.placemark.locality ?? "";entry["country"]=r.item.placemark.country ?? "";selection=entry;providerLabel="Apple"}.buttonStyle(.bordered)}
            }.padding(.vertical,6)}
            Text("Apple Maps · Nearby matching, not popularity ranking. Check map details with the venue.").font(.caption)
        }}
        Section("Privacy & sources"){
            Text("GPS is requested only when you tap Use my location. An entered area is resolved through Apple Maps. Google searches send a rounded coordinate and radius through your chosen server; notes, photos and history are never included.").font(.caption)
            NavigationLink("Optional Google discovery setup"){DiscoverySettings()}
            Link("Google terms",destination:URL(string:"https://maps.google.com/help/terms_maps/")!);Link("Google privacy",destination:URL(string:"https://policies.google.com/privacy")!)
        }
    }.navigationTitle("Discover")
    .onChange(of:location.point){_,value in if let value{point=value.rounded;clearResults();Task{await searchNearby(value.rounded)}}}
    .onChange(of:radius){_,_ in clearResults()}
    .sheet(item:$selection){entry in NavigationStack{VStack{if providerLabel=="Google"{Text("Give this place your own name and notes. Google details stay in discovery results.").font(.caption).padding()};EntryEditor(visit:false,seed:entry)}.toolbar{Button("Cancel"){selection=nil}}}}
    }
    func clearResults(){nearby=[];popular=[];hasNearby=false;hasPopular=false;error=""}
    @MainActor func resolveArea()async{busy=true;error="";clearResults();defer{busy=false};do{
        let request=MKLocalSearch.Request();request.naturalLanguageQuery=area;request.resultTypes = .address
        let response=try await MKLocalSearch(request:request).start();guard let item=response.mapItems.first else{throw PassportError.invalid("Area not found. Include the city and country.")};let c=item.placemark.coordinate;point=SearchPoint(lat:c.latitude,lon:c.longitude).rounded
        // Show the resolved area before a restaurant query; do not guess a restaurant.
        area=item.placemark.title ?? area
    }catch{self.error=error.localizedDescription}}
    @MainActor func searchNearby(_ p:SearchPoint)async{guard !busy,p.valid else{return};busy=true;error="";nearby=[];hasNearby=false;let r=radius;defer{busy=false};do{
        let centre=CLLocationCoordinate2D(latitude:p.lat,longitude:p.lon);let request=MKLocalPointsOfInterestRequest(center:centre,radius:Double(r));request.pointOfInterestFilter=MKPointOfInterestFilter(including:[.restaurant,.cafe,.bakery])
        let response=try await MKLocalSearch(request:request).start()
        if point==p && radius==r{nearby=response.mapItems.filter{CLLocation(latitude:$0.placemark.coordinate.latitude,longitude:$0.placemark.coordinate.longitude).distance(from:CLLocation(latitude:p.lat,longitude:p.lon))<=Double(r)}.enumerated().map{NearbyRestaurant(id:String($0.offset),item:$0.element)};hasNearby=true}
    }catch{self.error="Apple Maps search unavailable. Your saved passport is still available offline."}}
    @MainActor func searchPopular(_ p:SearchPoint)async{guard !busy,p.valid else{return};busy=true;error="";popular=[];hasPopular=false;let r=radius;defer{busy=false};do{
        let rounded=p.rounded;let response=try await DiscoveryClient.current().request("popular",body:["lat":.number(Decimal(rounded.lat)),"lon":.number(Decimal(rounded.lon)),"radius":.number(Decimal(r))])
        guard case .array?=response.object["places"] else{throw PassportError.invalid("Incomplete discovery response.")}
        let values=try response.object.list("places").map{try PopularPlace($0.object)}
        if point==p && radius==r{popular=values;checked=response.object.text("checkedAt");hasPopular=true}
    }catch{self.error=error.localizedDescription}}
}
struct PopularCard:View {
    let place:PopularPlace
    let save:()->Void
    var body:some View{VStack(alignment:.leading,spacing:8){Text(place.name).font(.headline);Text(place.address).font(.caption)
        if let rating=place.rating{Text(String(format:"%.1f / 5",rating)+(place.reviews.map{" · \($0) reviews"} ?? " · review count unavailable")).font(.caption)}else{Text("Rating unavailable").font(.caption)}
        HStack{if let url=place.url{Link("Open Google Maps",destination:url).buttonStyle(.bordered)};Button("Save my own note",action:save).buttonStyle(.bordered)}
    }.padding(.vertical,6)}
}
struct DiscoverySettings:View {
    @AppStorage("passport.discovery.endpoint") private var endpoint=""
    @State private var code=""
    @State private var message=""
    @State private var busy=false
    var body:some View{Form{
        Text("Apple Maps nearby discovery works without this setup. Optional Google popularity needs the included server deployed over HTTPS, with a server-only Places API key and billing enabled. Popularity does not measure recent trend growth.")
        TextField("HTTPS discovery server URL",text:$endpoint).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
        SecureField("Server access code",text:$code)
        Button("Save code and test"){Task{busy=true;defer{busy=false};do{guard code.utf8.allSatisfy({$0>=33 && $0<=126}),code.count<=200 else{throw PassportError.invalid("Access code must use visible characters without spaces.")};try DiscoveryKeychain.save(code,name:"access:"+endpoint);let result=try await DiscoveryClient(endpoint:endpoint,accessCode:code).request("status");message=result.object["configured"]?.bool==true ? "Google Places is configured on this server.":"Server connected. Set GOOGLE_MAPS_API_KEY on the server to enable popularity search."}catch{message=error.localizedDescription}}}.disabled(busy)
        Text(message)
        Text("Never put your Google API key here. The access code protects your own server; it is stored in Keychain and excluded from backups.").font(.caption)
        if let url=SafeLink.web(endpoint+"/privacy"){Link("Server privacy",destination:url)}
        if let url=SafeLink.web(endpoint+"/terms"){Link("Server terms",destination:url)}
    }.navigationTitle("Discovery connection").onAppear{code=DiscoveryKeychain.read("access:"+endpoint)}.onChange(of:endpoint){_,_ in code=DiscoveryKeychain.read("access:"+endpoint);message=""}}
}
