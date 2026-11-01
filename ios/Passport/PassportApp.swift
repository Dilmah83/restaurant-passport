import SwiftUI

@main struct PassportApp:App {
    @StateObject private var store=PassportStore()
    var body:some Scene{WindowGroup{TabView{
        NavigationStack{HomeScreen()}.tabItem{Label("Passport",systemImage:"fork.knife")}
        NavigationStack{HistoryScreen()}.tabItem{Label("History",systemImage:"book.closed")}
        NavigationStack{DiscoverScreen()}.tabItem{Label("Discover",systemImage:"location.magnifyingglass")}
        NavigationStack{SavedScreen()}.tabItem{Label("Want to visit",systemImage:"bookmark")}
        NavigationStack{BackupScreen()}.tabItem{Label("Backup",systemImage:"externaldrive")}
    }.tint(.black).preferredColorScheme(.light).environmentObject(store)}}
}
func money(_ n:Decimal)->String{n.formatted(.currency(code:"AUD"))}
struct FoodBanner:View {
    let title:String
    let subtitle:String
    var asset="FoodHero"
    var body:some View{ZStack(alignment:.bottomLeading){
        Image(asset).resizable().scaledToFill().saturation(0).frame(maxWidth:.infinity).frame(height:250).clipped().accessibilityHidden(true)
        LinearGradient(colors:[.black.opacity(0.1),.black.opacity(0.92)],startPoint:.top,endPoint:.bottom)
        VStack(alignment:.leading,spacing:10){Text(title).font(.system(.largeTitle,design:.serif,weight:.bold));Text(subtitle).font(.subheadline)}.foregroundStyle(.white).padding(24)
    }.frame(height:250).clipShape(RoundedRectangle(cornerRadius:22))}
}
struct EntryRow:View {
    let entry:Entry
    var visit=true
    var body:some View{HStack(spacing:14){
        if let data=entry.photoData,let image=UIImage(data:data){Image(uiImage:image).resizable().scaledToFill().frame(width:60,height:60).clipped().clipShape(RoundedRectangle(cornerRadius:10)).accessibilityHidden(true)}
        VStack(alignment:.leading,spacing:5){Text(entry["name"]).font(.headline);Text(entry.location).font(.caption).foregroundStyle(.secondary);Text(visit ? "\(entry["date"]) · \(entry["type"])":"\(entry["type"]) · \(entry["price"])").font(.caption)
            if visit{Text("\(entry.rating==0 ? "Unrated":String(repeating:"★",count:entry.rating)) · \(money(entry.total))").font(.caption)}
        }
        Spacer(minLength:0);if entry.favourite{Image(systemName:"heart.fill").accessibilityLabel("Favourite")}
    }.padding(.vertical,6)}
}
struct HomeScreen:View {
    @EnvironmentObject private var store:PassportStore
    var visits:[Entry]{store.archive.entries("visits")}
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:24){
        FoodBanner(title:"Good food.\nGreat memories.",subtitle:"YOUR RESTAURANT PASSPORT")
        if let error=store.storageError{Text(error).font(.caption)}
        LazyVGrid(columns:[GridItem(.adaptive(minimum:145))],alignment:.leading,spacing:20){
            stat("Restaurants",String(store.archive.uniqueRestaurants));stat("Visits",String(visits.count));stat("Total spent",money(store.archive.totalSpent));stat("Average rating",store.archive.averageRating.map{String(format:"%.1f / 5",$0)} ?? "Unrated")
            if !visits.isEmpty{stat("Per visit",money(store.archive.totalSpent/Decimal(visits.count)));stat("Per person / visit",money(visits.reduce(0){$0+$1.perPerson}/Decimal(visits.count)))}
        }
        NavigationLink{EntryEditor(visit:true)}label:{Label("Log a restaurant visit",systemImage:"plus").frame(maxWidth:.infinity).padding().background(.black,in:RoundedRectangle(cornerRadius:14)).foregroundStyle(.white)}
        if visits.isEmpty{Text("Your next favourite meal starts here.").font(.title2).fontDesign(.serif);Text("Log your first visit or import a backup from the original app in Backup.").foregroundStyle(.secondary)}
        if !visits.isEmpty{StatsSection(visits:visits)}
        Text("Recently tasted").font(.title2).fontDesign(.serif).bold()
        ForEach(visits.sorted{$0["date"]>$1["date"]}.prefix(5)){r in NavigationLink{EntryDetail(entry:r,visit:true)}label:{EntryRow(entry:r).foregroundStyle(.black)}}
        NavigationLink("Find your next table nearby"){DiscoverScreen()}.font(.headline)
    }.padding(20)}.background{Image("FoodTable").resizable().scaledToFill().saturation(0).opacity(0.035).ignoresSafeArea()}.navigationTitle("Passport")}
    func stat(_ title:String,_ value:String)->some View{VStack(alignment:.leading,spacing:5){Text(value).font(.title2).bold();Text(title).font(.caption).foregroundStyle(.secondary)}}
}
struct RankedRestaurant:Identifiable { let id:String;let name:String;let rating:Double }
struct StatsSection:View {
    let visits:[Entry]
    var restaurants:[String:[Entry]]{Dictionary(grouping:visits,by: \.restaurantKey)}
    var body:some View{VStack(alignment:.leading,spacing:14){
        Text("Your tastes, by the numbers").font(.title2).fontDesign(.serif).bold()
        DisclosureGroup("Most visited"){ForEach(restaurants.keys.sorted{restaurants[$0]!.count>restaurants[$1]!.count}.prefix(5),id:\.self){key in HStack{Text(restaurants[key]!.first!["name"]);Spacer();Text("\(restaurants[key]!.count) visits")}.font(.subheadline)}}
        DisclosureGroup("Highest rated"){ForEach(topRated){item in HStack{Text(item.name);Spacer();Text(String(format:"%.1f ★",item.rating))}}}
        DisclosureGroup("Favourite cuisines"){let grouped=Dictionary(grouping:visits,by:{$0["type"]});ForEach(grouped.keys.sorted{grouped[$0]!.count>grouped[$1]!.count},id:\.self){key in HStack{Text(key);Spacer();Text("\(grouped[key]!.count) visits · \(money(grouped[key]!.reduce(0){$0+$1.total}))")}.font(.caption)}}
        DisclosureGroup("Spending by month"){let grouped=Dictionary(grouping:visits,by:{String($0["date"].prefix(7))});ForEach(grouped.keys.sorted().reversed(),id:\.self){key in HStack{Text(key);Spacer();Text(money(grouped[key]!.reduce(0){$0+$1.total}))}.font(.caption)}}
    }}
    var topRated:[RankedRestaurant]{restaurants.compactMap{key,list -> RankedRestaurant? in let rated=list.filter{$0.rating>0};guard !rated.isEmpty else{return nil};return RankedRestaurant(id:key,name:list.first!["name"],rating:Double(rated.reduce(0){$0+$1.rating})/Double(rated.count))}.sorted{$0.rating>$1.rating}.prefix(5).map{$0}}
}
struct HistoryScreen:View {
    @EnvironmentObject private var store:PassportStore
    @State private var query=""
    @State private var sort="Newest"
    @State private var cuisine="All"
    @State private var minimum=0
    @State private var favourites=false
    var cuisines:[String]{["All"]+Set(store.archive.entries("visits").map{$0["type"]}).sorted()}
    var filtered:[Entry]{store.archive.entries("visits").filter{r in (cuisine=="All" || r["type"]==cuisine) && r.rating>=minimum && (!favourites || r.favourite) && (query.isEmpty || [r["name"],r.location,r["type"],r["order"],r["notes"]].joined(separator:" ").localizedCaseInsensitiveContains(query))}.sorted{sort=="Highest rated" ? $0.rating>$1.rating:sort=="Most expensive" ? $0.total>$1.total:$0["date"]>$1["date"]}}
    var body:some View{List{
        DisclosureGroup("Filter and sort"){
            Picker("Sort",selection:$sort){ForEach(["Newest","Highest rated","Most expensive"],id:\.self){Text($0)}}
            Picker("Cuisine",selection:$cuisine){ForEach(cuisines,id:\.self){Text($0)}}
            Picker("Minimum rating",selection:$minimum){Text("Any").tag(0);ForEach(1...5,id:\.self){Text("\($0)+ stars").tag($0)}}
            Toggle("Favourites only",isOn:$favourites)
        }
        if filtered.isEmpty{ContentUnavailableView("No visits found",systemImage:"fork.knife",description:Text("Add a visit or adjust your filters."))}
        ForEach(filtered){r in NavigationLink{EntryDetail(entry:r,visit:true)}label:{EntryRow(entry:r)}.swipeActions{Button("Delete",role:.destructive){store.remove(r,type:"visits")}}}
        Text(store.message).font(.caption)
    }.searchable(text:$query,prompt:"Restaurant, dish, place or notes").navigationTitle("Your history").toolbar{NavigationLink{EntryEditor(visit:true)}label:{Image(systemName:"plus").accessibilityLabel("Add visit")}}}
}
struct SavedScreen:View {
    @EnvironmentObject private var store:PassportStore
    @State private var sort="Date added"
    @State private var query=""
    var items:[Entry]{let list=store.archive.entries("wants").filter{query.isEmpty || ($0["name"]+" "+$0.location+" "+$0["why"]).localizedCaseInsensitiveContains(query)};return sort=="Date added" ? list:list.sorted{sort=="Cuisine" ? $0["type"]<$1["type"]:sort=="Price" ? $0["price"]<$1["price"]:$0.location<$1.location}}
    var body:some View{List{
        FoodBanner(title:"The next table.",subtitle:"PLACES YOU WANT TO TRY",asset:"FoodTable").listRowInsets(EdgeInsets()).listRowSeparator(.hidden)
        Picker("Sort",selection:$sort){ForEach(["Date added","Location","Cuisine","Price"],id:\.self){Text($0)}}
        if items.isEmpty{Text("Save a restaurant to try next, or discover nearby places.")}
        ForEach(items){r in NavigationLink{EntryDetail(entry:r,visit:false)}label:{EntryRow(entry:r,visit:false)}.swipeActions{Button("Remove",role:.destructive){store.remove(r,type:"wants")}}}
        Text(store.message).font(.caption)
    }.navigationTitle("Want to visit").searchable(text:$query).toolbar{NavigationLink{EntryEditor(visit:false)}label:{Image(systemName:"plus").accessibilityLabel("Add restaurant")}}}
}
