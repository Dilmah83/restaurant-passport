// swift-tools-version: 5.9
import PackageDescription
let package=Package(name:"PassportCore",products:[.library(name:"PassportCore",targets:["PassportCore"])],targets:[
    .target(name:"PassportCore",path:"Passport",exclude:["PassportApp.swift","PassportStore.swift","EntryScreens.swift","BackupScreen.swift","DiscoverScreen.swift","DiscoveryClient.swift","Assets.xcassets"],sources:["JSONValue.swift","PassportCore.swift","DiscoveryCore.swift"]),
    .testTarget(name:"PassportCoreTests",dependencies:["PassportCore"],path:"PassportTests",exclude:["NativeTests.swift"],sources:["CoreTests.swift"])
])
