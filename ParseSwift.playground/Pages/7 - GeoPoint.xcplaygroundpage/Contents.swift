//: [Previous](@previous)

import PlaygroundSupport
import Foundation
import ParseSwift

PlaygroundPage.current.needsIndefiniteExecution = true
initializeParse()

//: Create your own ValueTyped ParseObject
struct GameScore: ParseObject {
    //: Those are required for Object
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?
    var location: GeoPoint?
    //: Your own properties
    var score: Int

    //: a custom initializer
    init(score: Int) {
        self.score = score
    }
}

//: Define initial GameScores
var score = GameScore(score: 10)
score.location = GeoPoint(latitude: 40.0, longitude: -30.0)

/*: Query asynchronously (preferred way) - Performs work on background
    queue and returns to designated on designated callbackQueue.
    If no callbackQueue is specified it returns to main queue.
*/
score.save { result in
    switch result {
    case .success(let savedScore):
        assert(savedScore.objectId != nil)
        assert(savedScore.createdAt != nil)
        assert(savedScore.updatedAt != nil)
        assert(savedScore.ACL == nil)
        assert(savedScore.score == 10)
        assert(savedScore.location != nil)

        guard let location = savedScore.location else {
            print("Something went wrong")
            return
        }

        print(location.debugDescription)
    case .failure(let error):
        assertionFailure("Error saving: \(error)")
    }

}

//: [Next](@next)