import Testing
@testable import TextFlash

@Test func matcherFindsExactAbbreviation() {
    let matcher = SnippetMatcher()
    matcher.insert(abbreviation: "sig", expansion: "Regards")

    #expect(matcher.match(in: "sig") == SnippetMatch(abbreviation: "sig", expansion: "Regards"))
}

@Test func matcherFindsSuffixAfterUnrelatedInput() {
    let matcher = SnippetMatcher()
    matcher.insert(abbreviation: "addr", expansion: "123 Main")

    #expect(matcher.match(in: "helloaddr") == SnippetMatch(abbreviation: "addr", expansion: "123 Main"))
}

@Test func matcherWaitsOnPartialPrefix() {
    let matcher = SnippetMatcher()
    matcher.insert(abbreviation: "addr", expansion: "123 Main")

    #expect(matcher.match(in: "ad") == nil)
    #expect(matcher.trimToPossibleSuffix("xxad") == "ad")
}

@Test func matcherClearsImpossibleBuffer() {
    let matcher = SnippetMatcher()
    matcher.insert(abbreviation: "addr", expansion: "123 Main")

    #expect(matcher.match(in: "xyz") == nil)
    #expect(matcher.trimToPossibleSuffix("xyz") == "")
}

@Test func matcherRemovesAbbreviation() {
    let matcher = SnippetMatcher()
    matcher.insert(abbreviation: "sig", expansion: "Regards")
    matcher.remove(abbreviation: "sig")

    #expect(matcher.match(in: "sig") == nil)
}

@Test func matcherPrefersLongestSuffixAndWaitsForLongerPossiblePrefix() {
    let matcher = SnippetMatcher()
    matcher.insert(abbreviation: "abc", expansion: "long")
    matcher.insert(abbreviation: "bc", expansion: "short")
    #expect(matcher.match(in: "xabc") == SnippetMatch(abbreviation: "abc", expansion: "long"))

    matcher.insert(abbreviation: "abcd", expansion: "longer")
    matcher.remove(abbreviation: "abc")
    // abc 仍是 abcd 的有效前缀，不能提前展开其较短后缀 bc。
    #expect(matcher.match(in: "xabc") == nil)
    #expect(matcher.trimToPossibleSuffix("xabc") == "abc")
    #expect(matcher.match(in: "xabcd") == SnippetMatch(abbreviation: "abcd", expansion: "longer"))
}

@Test func matcherRemovalPreservesSharedBranchesAndUnicodeCharacters() {
    let matcher = SnippetMatcher()
    matcher.insert(abbreviation: "👩🏽‍💻", expansion: "developer")
    matcher.insert(abbreviation: "👩🏽‍💻好", expansion: "greeting")
    matcher.insert(abbreviation: "👩🏽‍💻你", expansion: "sibling")
    matcher.remove(abbreviation: "👩🏽‍💻好")
    #expect(matcher.match(in: "输入👩🏽‍💻好") == nil)
    #expect(matcher.match(in: "输入👩🏽‍💻你") == SnippetMatch(abbreviation: "👩🏽‍💻你", expansion: "sibling"))
    #expect(matcher.match(in: "输入👩🏽‍💻") == SnippetMatch(abbreviation: "👩🏽‍💻", expansion: "developer"))
    matcher.remove(abbreviation: "👩🏽‍💻")
    #expect(matcher.match(in: "输入👩🏽‍💻你") != nil)
    matcher.remove(abbreviation: "不存在")
    #expect(matcher.trimToPossibleSuffix("输入👩🏽‍💻") == "👩🏽‍💻")
}

@Test func matcherReplacementAndClearDiscardStaleExpansions() {
    let matcher = SnippetMatcher()
    matcher.insert(abbreviation: "sig", expansion: "old")
    matcher.insert(abbreviation: "sig", expansion: "new")
    #expect(matcher.match(in: "sig")?.expansion == "new")
    matcher.clear()
    #expect(matcher.match(in: "sig") == nil)
    #expect(matcher.trimToPossibleSuffix("si") == "")
    #expect(matcher.match(in: "") == nil)
    matcher.insert(abbreviation: "sig", expansion: "fresh")
    #expect(matcher.match(in: "sig")?.expansion == "fresh")
}
