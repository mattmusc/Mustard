# Example: Tokens with internal state

## Literal Matching

In examples so far, token types have looked at individual scalars without context to other scalars that have already been matched.

Without keeping some internal state of what's been matched so far, it's not possible to create a token that matches *cat* but not *cta* since they both start with the same scalar, and have the same set of characters.

A `LiteralToken` is a more complex `TokenType` that uses a target `String` as the basis for tokenization:

````Swift

// implementing as class rather than struct since `canTake(_:)` will have mutating effect.
class LiteralToken: TokenType {

    private let target: String
    private var position: String.UnicodeScalarIndex

    // required by the TokenType protocol, but non-sensical to use
    required convenience init() {
        self.init(target: "")
    }

    // instead, we should initalize instance with the target String we're looking for
    init(target: String) {
        self.target = target
        self.position = target.unicodeScalars.startIndex
    }

    // instead of looking at a set of scalars, the order that the scalar occurs
    // is relevent for the token
    func canTake(_ scalar: UnicodeScalar) -> Bool {

        guard position < target.unicodeScalars.endIndex else {
            return false
        }

        // if the scalar matches the target scalar in the current position, then advance
        // the position and return true
        if scalar == target.unicodeScalars[position] {
            position = target.unicodeScalars.index(after: position)
            return true
        }
        else {
            return false
        }
    }

    // this token is only complete when we've called `canTake(_:)` with the correct sequence
    // of scalars such that `position` has advanced to the endIndex of the target
    var isComplete: Bool {
        return position == target.unicodeScalars.endIndex
    }

    // if we've matched the token completely, it should be invalid if the next scalar
    // matches a letter, this means that literal match of "cat" will not match "catastrophe"
    func completeTokenIsInvalid(whenNextScalarIs scalar: UnicodeScalar?) -> Bool {
        if let next = scalar {
            return !CharacterSet.letters.contains(next)
        }
        else {
            return false
        }
    }

    // token instances are re-used, in most cases this doesn't matter, but because we keep
    // an internal state, we need to reset this instance to start matching again
    func prepareForReuse() {
        position = target.unicodeScalars.startIndex
    }
}

extension String {
    // a convenience to allow us to use `"cat".literalToken` instead of `LiteralToken("cat")`
    var literalToken: LiteralToken {
        return LiteralToken(target: self)
    }
}
````

This allows us to match tokens by specific words. Note in this example that the text 'catastrophe' is not matched.

````Swift
let input = "the cat and the catastrophe duck"
let matches = input.matches(from: "cat".literalToken, "duck".literalToken)
matches.count // -> 2

for match in matches {
    print("-", "'\(match.text)'")
}
// prints ->
// - 'cat'
// - 'duck'

````

## Template Matching

Another useful pattern would be allow us to look for a matching sequence of scalars but using a template rather than a literal match.

A `DateMatch` is a more complex `TokenType` that uses an internal template as the basis for tokenization:

````Swift

// convenience operator to make matching CharacterSet to scalar in a switch statement
infix operator ~=
func ~= (option: CharacterSet, input: UnicodeScalar) -> Bool {
    return option.contains(input)
}

class DateToken: TokenType {

    // private properties
    private let _template = "00/00/00"
    private var _position: String.UnicodeScalarIndex
    private var _dateText: String
    private var _date: Date?

    // public property
    var date: Date {
        return _date!
    }

    // formatters are expensive, so only instantiate once for all DateTokens
    static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yy"
        return dateFormatter
    }()

    // called when we access `DateToken.tokenizer`
    required init() {
        _position = _template.unicodeScalars.startIndex
        _dateText = ""
    }

    func canTake(_ scalar: UnicodeScalar) -> Bool {

        guard _position < _template.unicodeScalars.endIndex else {
            // we've matched all of the template
            return false
        }

        switch (_template.unicodeScalars[_position], scalar) {
        case ("\u{0030}", CharacterSet.decimalDigits), // match with a decimal digit
             ("\u{002F}", "\u{002F}"):                 // match with the '/' character

            _position = _template.unicodeScalars.index(after: _position) // increment the template position
            _dateText.unicodeScalars.append(scalar) // add scalar to text matched so far
            return true

        default:
            return false
        }
    }

    var isComplete: Bool {
        if _position == _template.unicodeScalars.endIndex,
            let date = DateToken.dateFormatter.date(from: _dateText) {
            // we've reached the end of the template
            // and the date text collected so far represents a valid
            // date format (e.g. not 99/99/99)

            _date = date
            return true
        }
        else {
            return false
        }
    }

    // reset the tokenizer for matching new date
    func prepareForReuse() {
        _dateText = ""
        _date = nil
        _position = _template.unicodeScalars.startIndex
    }

    // return an instance of tokenizer to return in matching tokens
    // we return a copy so that the instance keeps reference to the
    // dateText that has been matched, and the date that was parsed
    var tokenizerForMatch: TokenType {
        return DateToken(text: _dateText, date: _date)
    }

    // only used by `tokenizerForMatch`
    private init(text: String, date: Date?) {
        _dateText = text
        _date = date
        _position = text.unicodeScalars.startIndex
    }
}
````

This will match tokens for any text that has the format of three pairs of numbers joined with the '/' character, but will also ignore characters that match that format, but don't form a valid date.

Combined with the technique used in the [expressive matching example](Documentation/3. Expressive matching.md) where tokenizing using a single TokenType returns results of the actual type used, we can even access the `Date` object associated with the token.

````Swift
import Mustard

let messyInput = "Serial: #YF 1942-b 12/01/27 (Scanned) 12/03/27 (Arrived) ref: 99/99/99"

let dateMatches: [DateToken.Match] = messyInput.matches()
// dateMatches.count -> 2
// ('99/99/99' is not matched by `DateToken`)
//
// first date
// dateMatches[0].text -> "12/01/27"
// dateMatches[0].tokenizer -> DateToken()
// dateMatches[0].tokenizer.date -> Date(2027-12-01 05:00:00 +0000)
//
// last date
// dateMatches[1].text -> "12/03/27"
// dateMatches[1].tokenizer -> DateToken()
// dateMatches[1].tokenizer.date -> Date(2027-12-03 05:00:00 +0000)
````

See [FuzzyMatchTokenTests.swift](/Mustard/MustardTests/FuzzyMatchTokenTests.swift) for a unit test that includes fuzzy matching of a literal String, but ignoring certain characters.