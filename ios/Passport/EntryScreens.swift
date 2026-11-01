import SwiftUI
import PhotosUI
import ImageIO
import UniformTypeIdentifiers

struct EntryDetail:View {
    @EnvironmentObject private var store:PassportStore
    let entry:Entry
    let visit:Bool
    var current:Entry{store.archive.entries(visit ? "visits":"wants").first{$0.id==entry.id} ?? entry}
    var body:some View{List{
        if let data=current.photoData,let image=UIImage(data:data){Image(uiImage:image).resizable().scaledToFit().accessibilityLabel("Your restaurant photo")}
        Section{Text(current["name"]).font(.title2).fontDesign(.serif).bold();Text(current.location);Text(current["type"])}
        if visit{
            Section("Your visit"){Text(current["date"]);Text(current.rating==0 ? "Unrated":String(repeating:"★",count:current.rating));Text("\(money(current.total)) for \(current.people) · \(money(current.perPerson)) each");if current.favourite{Label("Favourite",systemImage:"heart.fill")};Text("Visit again: "+(current["again"]=="yes" ? "Yes":current["again"]=="no" ? "No":"Not sure"));Text(current["order"]);Text(current["notes"]).textSelection(.enabled)}
            NavigationLink("Log another visit"){EntryEditor(visit:true,seed:repeatVisit)}
        }else{
            Section("Saved for later"){Text(current["price"]);Text(current["why"])}
            NavigationLink("Mark visited"){EntryEditor(visit:true,seed:visitFromWant,removingWant:current.id)}
            Text("The saved place is removed only when you save the visit.").font(.caption)
        }
        NavigationLink("Edit"){EntryEditor(visit:visit,seed:current)}
    }.navigationTitle(visit ? "Visit":"Saved restaurant")}
    var repeatVisit:Entry{var next=Entry.new(visit:true);for key in ["name","suburb","city","country","type"]{next[key]=current[key]};return next}
    var visitFromWant:Entry{repeatVisit}
}
enum PassportPhoto {
    static func jpeg(_ data:Data) async throws->Data {
        try await Task.detached(priority:.userInitiated){
            guard data.count<=20*1024*1024,let source=CGImageSourceCreateWithData(data as CFData,nil),let image=CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:1400] as CFDictionary) else{throw PassportError.invalid("Choose a readable image under 20 MB.")}
            let out=NSMutableData();guard let target=CGImageDestinationCreateWithData(out,UTType.jpeg.identifier as CFString,1,nil) else{throw PassportError.invalid("Could not prepare photo.")};CGImageDestinationAddImage(target,image,[kCGImageDestinationLossyCompressionQuality:0.8] as CFDictionary);guard CGImageDestinationFinalize(target),out.length<=10*1024*1024 else{throw PassportError.invalid("Photo is too large.")};return out as Data
        }.value
    }
}
struct EntryEditor:View {
    @EnvironmentObject private var store:PassportStore
    @Environment(\.dismiss) private var dismiss
    let visit:Bool
    var seed:Entry?
    var removingWant:String?
    @State private var record=Entry()
    @State private var total="0"
    @State private var people="1"
    @State private var rating=0
    @State private var favourite=false
    @State private var photo:PhotosPickerItem?
    @State private var busy=false
    @State private var error=""
    @State private var loaded=false
    let cuisines=["Italian","Chinese","Japanese","Thai","Indian","Pizza","Pub","Steakhouse","Seafood","Cafe","Fast food","Mexican","Bakery","Other"]
    var body:some View{Form{
        Section("Restaurant"){
            TextField("Restaurant name",text:binding("name"));TextField("Suburb",text:binding("suburb"));TextField("City",text:binding("city"));TextField("Country",text:binding("country"))
            Picker("Cuisine",selection:binding("type")){ForEach(Array(Set(cuisines+[record["type"]])).filter{!$0.isEmpty}.sorted(),id:\.self){Text($0)}}
        }
        if visit{
            Section("Your experience"){
                DatePicker("Visited",selection:dateBinding,displayedComponents:.date)
                Picker("Your rating",selection:$rating){Text("Unrated").tag(0);ForEach(1...5,id:\.self){Text("\($0) stars").tag($0)}}
                TextField("Total cost (AUD)",text:$total).keyboardType(.decimalPad)
                TextField("Number of people",text:$people).keyboardType(.numberPad)
                if let amount=Decimal(string:total),let n=Int(people),n>0{Text("\(money(amount/Decimal(n))) per person").font(.caption)}
                TextField("What I ordered",text:binding("order"),axis:.vertical);TextField("Food, service and atmosphere",text:binding("notes"),axis:.vertical)
                Toggle("Favourite",isOn:$favourite)
                Picker("Visit again?",selection:binding("again")){Text("Not sure").tag("");Text("Yes").tag("yes");Text("No").tag("no")}
            }
            Section("Your photo"){
                if let data=record.photoData,let image=UIImage(data:data){Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:200)}
                PhotosPicker(selection:$photo,matching:.images){Label("Choose a food photo",systemImage:"photo")}.disabled(busy)
                if !record["photo"].isEmpty{Button("Remove photo",role:.destructive){record["photo"]="";photo=nil}}
                if busy{ProgressView("Preparing photo…")}
                Text("Only your selected image is accessed. A compressed copy is kept offline and included in backups.").font(.caption)
            }
        }else{
            Section("Why this place?"){
                Picker("Price",selection:binding("price")){ForEach(["","$","$$","$$$","$$$$"],id:\.self){Text($0.isEmpty ? "Unknown":$0).tag($0)}}
                TextField("Why I want to go",text:binding("why"),axis:.vertical)
            }
        }
        Text(error).foregroundStyle(.primary)
        Button("Save"){save()}.disabled(busy || store.storageError != nil)
    }.navigationTitle(visit ? "Log a visit":"Save a restaurant")
    .onAppear{guard !loaded else{return};loaded=true;record=seed ?? Entry.new(visit:visit);total=NSDecimalNumber(decimal:record.total).stringValue;people=String(record.people);rating=record.rating;favourite=record.favourite}
    .onChange(of:photo){_,item in guard let item else{return};Task{busy=true;defer{busy=false};do{guard let data=try await item.loadTransferable(type:Data.self) else{throw PassportError.invalid("Photo unavailable. Download it from iCloud and try again.")};let jpeg=try await PassportPhoto.jpeg(data);record["photo"]="data:image/jpeg;base64,"+jpeg.base64EncodedString()}catch{self.error=error.localizedDescription}}}
    }
    func binding(_ key:String)->Binding<String>{Binding(get:{record[key]},set:{record[key]=$0})}
    var dateBinding:Binding<Date>{Binding(get:{let p=record["date"].split(separator:"-").compactMap{Int($0)};return p.count==3 ? Calendar.current.date(from:DateComponents(year:p[0],month:p[1],day:p[2],hour:12)) ?? Date():Date()},set:{let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.dateFormat="yyyy-MM-dd";record["date"]=f.string(from:$0)})}
    func save(){do{
        if visit{let raw=total.isEmpty ? "0":total;guard raw.range(of:#"^[0-9]+(\.[0-9]+)?$"#,options:.regularExpression) != nil,let amount=Decimal(string:raw,locale:Locale(identifier:"en_US_POSIX")),let n=Int(people) else{throw PassportError.invalid("Enter a non-negative cost using a decimal point and a whole number of people.")};record.fields["total"] = .number(amount);record.fields["people"] = .number(Decimal(n));record.fields["rating"] = .number(Decimal(rating));record.fields["fav"] = .bool(favourite)}
        try store.save(record,type:visit ? "visits":"wants",removingWant:removingWant);dismiss()
    }catch{self.error=error.localizedDescription}}
}
