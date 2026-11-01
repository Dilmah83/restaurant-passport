import SwiftUI
import UniformTypeIdentifiers

struct PassportDocument:FileDocument {
    static var readableContentTypes:[UTType]{[.json,.commaSeparatedText]}
    var data:Data
    init(_ data:Data){self.data=data}
    init(configuration:ReadConfiguration)throws{data=configuration.file.regularFileContents ?? Data()}
    func fileWrapper(configuration:WriteConfiguration)throws->FileWrapper{FileWrapper(regularFileWithContents:data)}
}
struct BackupScreen:View {
    @EnvironmentObject private var store:PassportStore
    @State private var importing=false
    @State private var exporting=false
    @State private var export=Data()
    @State private var exportType=UTType.json
    @State private var pending:PassportArchive?
    @State private var confirm=false
    @State private var message=""
    @AppStorage("passport.lastExport") private var lastExport=""
    var body:some View{Form{
        Section("Your passport, your data"){
            Text("\(store.archive.entries("visits").count) visits · \(store.archive.entries("wants").count) saved restaurants")
            Text("On the original website: Backup → Save backup (JSON). Save it to Files, then import here. The native app cannot directly read Safari's IndexedDB. Imports add missing IDs and preserve existing records.").font(.caption)
            Button("Import website or native backup"){importing=true}.disabled(store.storageError != nil)
            Button("Export full JSON backup"){do{export=try store.exported();exportType = .json;exporting=true}catch{message=error.localizedDescription}}.disabled(store.storageError != nil)
            Button("Export visits spreadsheet (CSV)"){export=Data(store.archive.csv().utf8);exportType = .commaSeparatedText;exporting=true}.disabled(store.storageError != nil)
            if !lastExport.isEmpty{Text("Last successful export: "+lastExport).font(.caption)}
            if store.canUndo{Button("Undo last saved change or import"){do{try store.undo()}catch{message=error.localizedDescription}}}
            if let error=store.storageError{Text(error);Button("Export unreadable original for recovery"){do{export=try store.originalData();exportType = .json;exporting=true}catch{message=error.localizedDescription}}}
            Text(message).textSelection(.enabled);Text(store.message)
        }
        NavigationLink("Discovery connection"){DiscoverySettings()}
        Section("Privacy"){
            Text("Visits, notes and photos stay on this device. No account or automatic sync. iPhone backups follow your Apple settings. Your selected location is shared with Apple Maps when searching. Optional Google popularity search sends only a rounded location and radius through your configured server to Google. Your visit history and photos are never sent for discovery.")
            Text("JSON exports include your photos and notes. Keep backups outside this app and share only with intended recipients. There is no verified real-time trending feed: Google popularity is labelled separately from nearby Apple results.")
        }
        Section("Photography"){
            Text("Food-photo backgrounds are decorative stock images, not photographs of suggested restaurants. Images display in monochrome. User photos retain their original colours.").font(.caption)
            Link("Food imagery · Unsplash",destination:URL(string:"https://unsplash.com/license")!)
        }
    }.navigationTitle("Backup & settings")
    .fileImporter(isPresented:$importing,allowedContentTypes:[.json]){result in do{let url=try result.get();let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}};guard (try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)<=100*1024*1024 else{throw PassportError.invalid("Backup exceeds 100 MB.")};pending=try PassportArchive.decode(Data(contentsOf:url));confirm=true}catch{message=error.localizedDescription}}
    .confirmationDialog("Import missing records? Existing records win matching-ID conflicts. A recovery copy is kept.",isPresented:$confirm,titleVisibility:.visible){Button("Import and keep existing records"){do{if let pending{try store.restore(pending)};pending=nil}catch{message=error.localizedDescription}};Button("Cancel",role:.cancel){pending=nil}}
    .fileExporter(isPresented:$exporting,document:PassportDocument(export),contentType:exportType,defaultFilename:"restaurant-passport-"+CivilDay.today){result in switch result{case .success:lastExport=CivilDay.today;message="Exported. Keep a separate copy.";case .failure(let error):message=error.localizedDescription}}
    }
}
