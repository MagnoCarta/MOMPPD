import SwiftUI

//struct MessagingView: View {
//    @StateObject var client = UserClient(username: User.shared.name)
//    @State private var dmMessage = ""
//    @State private var dmTargetUser = ""
//    @State private var topicName = ""
//    @State private var topicMessage = ""
//    
//    var body: some View {
//        VStack {
//            List(client.messages, id: \.self) { msg in Text(msg) }
//            
//            // Direct Message Section
//            Text("Direct Message")
//                .font(.headline)
//            HStack {
//                TextField("Recipient username", text: $dmTargetUser)
//                TextField("Your message", text: $dmMessage)
//                Button("Send DM") {
//                    client.sendDirectMessage(to: dmTargetUser, content: dmMessage)
//                    dmMessage = ""
//                }
//            }
//            
//            Divider().padding(.vertical)
//            
//            // Topic Section
//            Text("Topic Messaging")
//                .font(.headline)
//            HStack {
//                TextField("Topic name", text: $topicName)
//                Button("Subscribe") { client.subscribe(to: topicName) }
//                Button("Unsubscribe") { client.unsubscribe(from: topicName) }
//            }
//            
//            HStack {
//                TextField("Topic message", text: $topicMessage)
//                Button("Send to Topic") {
//                    client.sendTopicMessage(topic: topicName, content: topicMessage)
//                    topicMessage = ""
//                }
//            }
//        }
//        .padding()
//    }
//}


//struct NameView: View {
//    
//    @Bindable var user: User = .shared
//    
//    var body: some View {
//        NavigationStack {
//            VStack {
//                TextField("Whats your name?", text: $user.name)
//                NavigationLink("Enter") {
//                    MessagingView()
//                }
//            }
//        }
//    }
//}

@Observable
class User {
    
    static var shared: User = .init()
    
    var name: String = "Alice"
    
}
