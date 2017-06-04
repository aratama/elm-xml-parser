module XmlParserTest exposing (..)

import Test exposing (..)
import Expect exposing (Expectation)
import Fuzz exposing (list, int, string)
import XmlParser exposing (..)


expectPI : String -> List ProcessingInstruction -> (() -> Expectation)
expectPI source pis =
    \_ ->
        case XmlParser.parse source of
            Ok ast ->
                Expect.equal ast.processingInstructions pis

            Err e ->
                Expect.fail (toString e)


expectDocType : String -> Maybe DocType -> (() -> Expectation)
expectDocType source docType =
    \_ ->
        case XmlParser.parse source of
            Ok ast ->
                Expect.equal ast.docType docType

            Err e ->
                Expect.fail (toString e)


expectSucceed : String -> Node -> (() -> Expectation)
expectSucceed source node =
    \_ ->
        case XmlParser.parse source of
            Ok ast ->
                Expect.equal ast.root node

            Err e ->
                Expect.fail (toString e)


expectFail : String -> (() -> Expectation)
expectFail source =
    \_ ->
        case XmlParser.parse source of
            Ok ast ->
                Expect.fail ("Unexpectedly succeeded: " ++ toString ast)

            Err e ->
                Expect.pass


suite : Test
suite =
    describe "XmlParser"
        [ test "tagName" <| expectSucceed "<a/>" (Element "a" [] [])
        , test "tagName number" <| expectSucceed "<1/>" (Element "1" [] [])
        , test "tagName unicode 1" <| expectSucceed "<あ/>" (Element "あ" [] [])
        , test "tagName unicode 2" <| expectSucceed "<😄/>" (Element "😄" [] [])
        , test "tagName surrogate pairs" <| expectSucceed "<𩸽/>" (Element "𩸽" [] [])
        , test "tagName namespace" <| expectSucceed "<a:b/>" (Element "a:b" [] [])
        , test "tagName fail 1" <| expectFail "</>"
        , test "tagName fail 2" <| expectFail "<a>"
        , test "tagName fail 3" <| expectFail "<1>"
        , test "attribute 1" <| expectSucceed """<a b=""/>""" (Element "a" [ Attribute "b" "" ] [])
        , test "attribute 2" <| expectSucceed """<a b="1=</>"/>""" (Element "a" [ Attribute "b" "1=</>" ] [])
        , test "attribute quote 1" <| expectSucceed """<a b='""'/>""" (Element "a" [ Attribute "b" "\"\"" ] [])
        , test "attribute quote 2" <| expectSucceed """<a b="''"/>""" (Element "a" [ Attribute "b" "''" ] [])
        , test "attribute key number" <| expectSucceed """<a 1=""/>""" (Element "a" [ Attribute "1" "" ] [])
        , test "attribute key unicode 1" <| expectSucceed """<a あ=""/>""" (Element "a" [ Attribute "あ" "" ] [])
        , test "attribute key unicode 2" <| expectSucceed """<a 😄=""/>""" (Element "a" [ Attribute "😄" "" ] [])
        , test "attribute key surrogate pairs" <| expectSucceed """<a 𩸽=""/>""" (Element "a" [ Attribute "𩸽" "" ] [])
        , test "attribute key namespace" <| expectSucceed """<a b:c=""/>""" (Element "a" [ Attribute "b:c" "" ] [])
        , test "attribute fail 1" <| expectFail """<a a=/>"""
        , test "attribute fail 2" <| expectFail """<a a"="/>"""
        , test "attribute fail 3" <| expectFail """<a=""/>"""
        , test "attribute fail 4" <| expectFail """<a b c=""/>"""
        , test "attribute fail 5" <| expectFail """<a= b=""/>"""
        , test "attribute value escape 1" <| expectSucceed """<a a="&quot;"/>""" (Element "a" [ Attribute "a" "\"" ] [])
        , test "attribute fail same names" <| expectFail """<a b="" b=""/>"""
        , test "closing 1" <| expectSucceed "<a></a>" (Element "a" [] [])
        , test "closing 2" <| expectFail "<a></b>"
        , test "children text" <| expectSucceed "<a>1</a>" (Element "a" [] [ Text "1" ])
        , test "children text escape 1" <| expectSucceed "<a>&amp;</a>" (Element "a" [] [ Text "&" ])
        , test "children text escape 2" <| expectSucceed "<a>&#x41;</a>" (Element "a" [] [ Text "A" ])
        , test "children text escape 3" <| expectSucceed "<a>&#65;</a>" (Element "a" [] [ Text "A" ])
        , test "children text escape fail" <| expectFail "<a>&&;</a>"
        , test "children element 1" <| expectSucceed "<a><b/></a>" (Element "a" [] [ Element "b" [] [] ])
        , test "children element 2" <| expectSucceed "<a><b/><c></c></a>" (Element "a" [] [ Element "b" [] [], Element "c" [] [] ])
        , test "children element 3" <|
            expectSucceed "<a>1<b/>2<c>3</c>4</a>"
                (Element "a" [] [ Text "1", Element "b" [] [], Text "2", Element "c" [] [ Text "3" ], Text "4" ])
        , test "children element nested same tag" <| expectSucceed "<a><a></a></a>" (Element "a" [] [ Element "a" [] [] ])
        , test "children element fail" <| expectFail "<a><b></a></a>"
        , test "no root" <| expectFail ""
        , test "many roots" <| expectFail "<a/><a/>"
        , test "processing instruction 0" <| expectPI """<?xml ?><a/>""" [ ProcessingInstruction "xml" "" ]
        , test "processing instruction 1" <| expectPI """<?xml a?><a/>""" [ ProcessingInstruction "xml" "a" ]
        , test "processing instruction 2" <| expectPI """<?xml a="b" c="d"?><a/>""" [ ProcessingInstruction "xml" "a=\"b\" c=\"d\"" ]
        , test "processing instruction 3" <| expectPI """<?xml ??><a/>""" [ ProcessingInstruction "xml" "?" ]
        , test "processing instruction 4" <| expectPI """<?xml 1?2?><a/>""" [ ProcessingInstruction "xml" "1?2" ]
        , test "processing instruction multiple 1" <| expectPI """<?xml ?><?xml ?><a/>""" [ ProcessingInstruction "xml" "", ProcessingInstruction "xml" "" ]
        , test "processing instruction multiple 2" <| expectPI """<?xml ?>\x0D\t <?xml ?><a/>""" [ ProcessingInstruction "xml" "", ProcessingInstruction "xml" "" ]
        , test "doc type public 1" <| expectDocType """<!DOCTYPE a PUBLIC "" ""><a/>""" (Just (DocType "a" (Public "" "" Nothing)))
        , test "doc type public 2" <| expectDocType """<!DOCTYPE a PUBLIC "1" "2"><a/>""" (Just (DocType "a" (Public "1" "2" Nothing)))
        , test "doc type public 3" <| expectDocType """<!DOCTYPE a PUBLIC "" ""[]><a/>""" (Just (DocType "a" (Public "" "" (Just ""))))
        , test "doc type public 4" <| expectDocType """<!DOCTYPE a PUBLIC "" ""[a]><a/>""" (Just (DocType "a" (Public "" "" (Just "a"))))
        , test "doc type public fail 1" <| expectFail """<!DOCTYPE a PUBLIC ""><a/>"""
        , test "doc type public fail 2" <| expectFail """<!DOCTYPE PUBLIC "" ""><a/>"""
        , test "doc type system 1" <| expectDocType """<!DOCTYPE a SYSTEM ""><a/>""" (Just (DocType "a" (System "" Nothing)))
        , test "doc type system 2" <| expectDocType """<!DOCTYPE a SYSTEM "1"><a/>""" (Just (DocType "a" (System "1" Nothing)))
        , test "doc type system 3" <| expectDocType """<!DOCTYPE a SYSTEM "" []><a/>""" (Just (DocType "a" (System "" (Just ""))))
        , test "doc type system 4" <| expectDocType """<!DOCTYPE a SYSTEM "" [a]><a/>""" (Just (DocType "a" (System "" (Just "a"))))
        , test "doc type system fail 1" <| expectFail """<!DOCTYPE a SYSTEM []><a/>"""
        , test "doc type system fail 2" <| expectFail """<!DOCTYPE SYSTEM "" []><a/>"""
        , test "doc type custom 1" <| expectDocType """<!DOCTYPE a []><a/>""" (Just (DocType "a" (Custom "")))
        , test "doc type custom 2" <| expectDocType """<!DOCTYPE a [a]><a/>""" (Just (DocType "a" (Custom "a")))
        , test "doc type custom fail 1" <| expectFail """<!DOCTYPE a "" []><a/>"""
        , test "doc type custom fail 2" <| expectFail """<!DOCTYPE []><a/>"""
        , test "cdata 1" <| expectSucceed "<a><![CDATA[]]></a>" (Element "a" [] [])
        , test "cdata 2" <| expectSucceed "<a>a<![CDATA[]]></a>" (Element "a" [] [ Text "a" ])
        , test "cdata 3" <| expectSucceed "<a><![CDATA[b]]></a>" (Element "a" [] [ Text "b" ])
        , test "cdata 4" <| expectSucceed "<a><![CDATA[]]>c</a>" (Element "a" [] [ Text "c" ])
        , test "cdata 5" <| expectSucceed "<a>a<![CDATA[b]]></a>" (Element "a" [] [ Text "ab" ])
        , test "cdata 6" <| expectSucceed "<a><![CDATA[b]]>c</a>" (Element "a" [] [ Text "bc" ])
        , test "cdata 7" <| expectSucceed "<a>a<![CDATA[]]>c</a>" (Element "a" [] [ Text "ac" ])
        , test "cdata 8" <| expectSucceed "<a>a<![CDATA[b]]>c</a>" (Element "a" [] [ Text "abc" ])
        , test "whitespace" <| expectSucceed "\x0D\n\t <?xml ?>\x0D\n\t <!DOCTYPE a []>\x0D\n\t <a/>\x0D\n\t " (Element "a" [] [])
        ]



{-
   http://www.oracle.com/technetwork/articles/wang-whitespace-092897.html

   xml:space
    preserve|default
   xsl:strip-space
   xsl:preserve-space
   normalize-space()
-}
