import Foundation

enum PassportError: LocalizedError { case invalid(String); var errorDescription:String? { if case .invalid(let s)=self{return s};return nil } }
struct Entry: Identifiable, Equatable {
    var fields:[String:JSONValue]
    init(_ fields:[String:JSONValue]=[:]) { self.fields=fields }
    var id:String{self["id"]}
    subscript(_ key:String)->String{ get{fields.text(key)} set{fields[key] = .string(newValue)} }
    var rating:Int{NSDecimalNumber(decimal:fields["rating"]?.decimal ?? 0).intValue}
    var total:Decimal{fields["total"]?.decimal ?? 0}
    var people:Int{max(1,NSDecimalNumber(decimal:fields["people"]?.decimal ?? 1).intValue)}
    var perPerson:Decimal{total/Decimal(people)}
    var favourite:Bool{fields["fav"]?.bool ?? false}
    var location:String{[self["suburb"],self["city"],self["country"]].filter{!$0.isEmpty}.joined(separator:", ")}
    var restaurantKey:String{(self["name"].trimmingCharacters(in:.whitespacesAndNewlines)+"|"+self["suburb"].trimmingCharacters(in:.whitespacesAndNewlines)).lowercased()}
    static func new(visit:Bool)->Entry{
        var r=Entry(["id":.string(UUID().uuidString),"country":.string("Australia"),"type":.string("Other")])
        if visit{r["date"]=CivilDay.today;r.fields["rating"] = .number(0);r.fields["total"] = .number(0);r.fields["people"] = .number(1);r.fields["fav"] = .bool(false)}
        return r
    }
    var photoData:Data?{let s=self["photo"];guard let comma=s.firstIndex(of:",") else{return nil};return Data(base64Encoded:String(s[s.index(after:comma)...]))}
}
enum CivilDay {
    static func date(_ s:String)->Date?{let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.timeZone=TimeZone(secondsFromGMT:0);f.dateFormat="yyyy-MM-dd";f.isLenient=false;guard s.count==10,let d=f.date(from:s),f.string(from:d)==s else{return nil};return d}
    static var today:String{let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.dateFormat="yyyy-MM-dd";return f.string(from:Date())}
}
struct PassportArchive:Equatable {
    var root:[String:JSONValue]=["app":.string("restaurant-passport"),"version":.number(1),"visits":.array([]),"wants":.array([])]
    func entries(_ type:String)->[Entry]{root.list(type).map{Entry($0.object)}}
    mutating func set(_ type:String,_ values:[Entry]){root[type] = .array(values.map{.object($0.fields)})}
    static func decode(_ data:Data)throws->PassportArchive {
        guard data.count<=100*1024*1024 else{throw PassportError.invalid("Backup exceeds 100 MB.")}
        let value=try JSONDecoder().decode(JSONValue.self,from:data)
        var archive=PassportArchive()
        switch value {
        case .array: archive.root["visits"]=value
        case .object(let fields):
            guard fields["app"] == nil || fields.text("app")=="restaurant-passport",fields["version"] == nil || fields["version"]?.decimal==1,fields["visits"] != nil || fields["wants"] != nil else{throw PassportError.invalid("Not a supported Restaurant Passport backup.")}
            fields.forEach{archive.root[$0.key]=$0.value}
        default:throw PassportError.invalid("Invalid backup structure.")
        }
        try archive.validate();return archive
    }
    func encoded()throws->Data {try validate();let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];return try encoder.encode(JSONValue.object(root))}
    func validate()throws {
        for type in ["visits","wants"] {
            guard case .array(let values)?=root[type],values.count<=10000 else{throw PassportError.invalid("Invalid or oversized \(type) list.")}
            var ids=Set<String>()
            for v in values {guard case .object(let fields)=v else{throw PassportError.invalid("Invalid restaurant record.")};let r=Entry(fields);guard ids.insert(r.id).inserted else{throw PassportError.invalid("Duplicate record IDs in backup.")};try Self.validate(r,type:type)}
        }
    }
    static func validate(_ r:Entry,type:String)throws {
        guard !r.id.isEmpty,!r["name"].trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{throw PassportError.invalid("Enter a restaurant name.")}
        if type=="visits" {
            guard CivilDay.date(r["date"]) != nil else{throw PassportError.invalid("Use a real date in YYYY-MM-DD format.")}
            guard let rating=r.fields["rating"]?.decimal,rating>=0,rating<=5,rating==Decimal(r.rating),let people=r.fields["people"]?.decimal,people>=1,people<=10000,people==Decimal(r.people),let total=r.fields["total"]?.decimal,total>=0,total<=1_000_000_000 else{throw PassportError.invalid("Rating must be 0–5, people a whole number of at least 1, and cost a non-negative AUD amount.")}
            if !r["photo"].isEmpty {guard r["photo"].hasPrefix("data:image/jpeg;base64,") || r["photo"].hasPrefix("data:image/png;base64,") || r["photo"].hasPrefix("data:image/webp;base64,"),let data=r.photoData,!data.isEmpty,data.count<=10*1024*1024 else{throw PassportError.invalid("Invalid photo or photo exceeds 10 MB.")}}
        }
    }
    func merging(_ incoming:PassportArchive)throws->(PassportArchive,Int){
        var next=self;var count=0
        for type in ["visits","wants"]{var values=entries(type);let ids=Set(values.map(\.id));let added=incoming.entries(type).filter{!ids.contains($0.id)};count+=added.count;values+=added;next.set(type,values)}
        // Existing records and unknown metadata win conflicts; new metadata is retained.
        incoming.root.filter{!["visits","wants","app","version","exported"].contains($0.key)}.forEach{if next.root[$0.key]==nil{next.root[$0.key]=$0.value}}
        try next.validate();return(next,count)
    }
    var totalSpent:Decimal{entries("visits").reduce(0){$0+$1.total}}
    var uniqueRestaurants:Int{Set(entries("visits").map(\.restaurantKey)).count}
    var averageRating:Double?{let rated=entries("visits").filter{$0.rating>0};return rated.isEmpty ? nil:Double(rated.reduce(0){$0+$1.rating})/Double(rated.count)}
    func csv()->String{
        func quote(_ input:String)->String{let unsafe=["=","+","-","@","\t","\r"].contains{input.trimmingCharacters(in:.whitespacesAndNewlines).hasPrefix($0)};return "\""+(unsafe ? "'"+input:input).replacingOccurrences(of:"\"",with:"\"\"")+"\""}
        let header="name,suburb,city,country,date,type,rating,total,people,costPerPerson,order,notes,favourite,visitAgain"
        return "\u{FEFF}"+header+"\r\n"+entries("visits").map{r in [r["name"],r["suburb"],r["city"],r["country"],r["date"],r["type"],String(r.rating),NSDecimalNumber(decimal:r.total).stringValue,String(r.people),NSDecimalNumber(decimal:r.perPerson).stringValue,r["order"],r["notes"],r.favourite ? "yes":"no",r["again"]].map(quote).joined(separator:",")}.joined(separator:"\r\n")
    }
}
