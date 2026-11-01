import SwiftUI

@MainActor final class PassportStore:ObservableObject {
    @Published private(set) var archive=PassportArchive()
    @Published var storageError:String?
    @Published var message=""
    private let file:URL
    private let recovery:URL
    init(directory:URL?=nil){
        let folder=directory ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("RestaurantPassport")
        file=folder.appendingPathComponent("passport.json");recovery=folder.appendingPathComponent("before-change.json")
        do{try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);if FileManager.default.fileExists(atPath:file.path){archive=try PassportArchive.decode(Data(contentsOf:file))}}catch{storageError="Existing data could not be read and was not overwritten. Export it for recovery. "+error.localizedDescription}
    }
    var canUndo:Bool{FileManager.default.fileExists(atPath:recovery.path)}
    func commit(_ next:PassportArchive,snapshot:Bool=true)throws{
        guard storageError==nil else{throw PassportError.invalid("Storage needs recovery before changes can be saved.")}
        let data=try next.encoded();guard data.count<=100*1024*1024 else{throw PassportError.invalid("Passport exceeds 100 MB. Export a backup and reduce photo sizes.")}
        if snapshot{try archive.encoded().write(to:recovery,options:[.atomic,.completeFileProtection])}
        try data.write(to:file,options:[.atomic,.completeFileProtection]);archive=next
    }
    func save(_ record:Entry,type:String,removingWant:String?=nil)throws{
        try PassportArchive.validate(record,type:type);var next=archive;var list=next.entries(type)
        if let i=list.firstIndex(where:{$0.id==record.id}){list[i]=record}else{list.append(record)}
        next.set(type,list)
        if let removingWant{next.set("wants",next.entries("wants").filter{$0.id != removingWant})}
        try commit(next)
    }
    func remove(_ record:Entry,type:String){do{var next=archive;next.set(type,next.entries(type).filter{$0.id != record.id});try commit(next);message="Deleted. Undo is available in Backup."}catch{message=error.localizedDescription}}
    func restore(_ incoming:PassportArchive)throws{let(next,count)=try archive.merging(incoming);try commit(next);message="Added \(count) records. Existing IDs were kept. Undo is available."}
    func undo()throws{let old=try PassportArchive.decode(Data(contentsOf:recovery));try commit(old,snapshot:false);message="Previous passport restored."}
    func originalData()throws->Data{try Data(contentsOf:file)}
    func exported()throws->Data{var next=archive;next.root["exported"] = .string(ISO8601DateFormatter().string(from:Date()));return try next.encoded()}
}
