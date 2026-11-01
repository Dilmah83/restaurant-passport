import Foundation

struct SearchPoint:Equatable {var lat:Double;var lon:Double
    var valid:Bool{lat.isFinite && lon.isFinite && (-90...90).contains(lat) && (-180...180).contains(lon)}
    var rounded:SearchPoint{.init(lat:(lat*1000).rounded()/1000,lon:(lon*1000).rounded()/1000)}
}
struct PopularPlace:Identifiable,Equatable {
    let id:String;let name:String;let address:String;let rating:Double?;let reviews:Int?;let url:URL?
    init(_ obj:[String:JSONValue])throws{
        id=obj.text("id");name=obj.text("name");address=obj.text("address")
        guard !id.isEmpty,!name.isEmpty else{throw PassportError.invalid("The place provider returned an incomplete record.")}
        let r=obj["rating"]?.decimal.map{NSDecimalNumber(decimal:$0).doubleValue};rating=(r != nil && r!>=0 && r!<=5) ? r:nil
        let count=obj["reviews"]?.decimal.map{NSDecimalNumber(decimal:$0).intValue};reviews=(count != nil && count!>=0) ? count:nil
        url=SafeLink.google(obj.text("url"))
    }
}
enum SafeLink {
    static func web(_ raw:String)->URL?{guard let url=URL(string:raw),["http","https"].contains(url.scheme?.lowercased() ?? ""),url.host != nil,url.user==nil,url.password==nil else{return nil};return url}
    static func google(_ raw:String)->URL?{guard let url=web(raw),let host=url.host?.lowercased(),host=="maps.google.com" || host=="www.google.com" || host=="maps.app.goo.gl" else{return nil};return url}
}
