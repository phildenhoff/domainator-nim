import strformat
import strutils
import macros
import terminal

import asynchttpserver, asyncdispatch

var TOP_LEVEL_DOMAINS: seq[string]

type
    # An instance of a "hacked" domain, in the format of <domain>.<topLevelDomain>/<path>
    DomainHack = object
        domain: string
        topLevelDomain: string
        path: string

#[ Helper method fro printing DomainHack objects.
]#
proc toString(this: DomainHack): string =
    return fmt"{this.domain}.{this.topLevelDomain}{this.path}"

#[ Search a phrase (`query`) for matching domains from a sequence.

    A domain with match a query if that domain is a subsequence of the query.
    For example, a query of "acomputer" will match both the domains "co" and 
    "com", so you receive two DomainHacks objects that will match the two
    domains.
]#
proc getMatchesForPhrase(query: string, domains: seq[string]): seq[DomainHack] =
    var matchingDomains: seq[DomainHack]

    for domain in domains:
        let santizedDomain = domain.strip().toLower()

        if contains(query, santizedDomain):
            var domainResult: DomainHack
            let splitQuery = split(query, santizedDomain)

            if startsWith(query, santizedDomain):
                continue
            elif endsWith(query, santizedDomain):
                domainResult = DomainHack(
                    domain: splitQuery[0],
                    topLevelDomain: santizedDomain, 
                    path: "",
                )
            else:
                let remainder = fmt"/{splitQuery[1]}"
                domainResult = DomainHack(
                    domain: splitQuery[0],
                    topLevelDomain: santizedDomain,
                    path: remainder
                )
            
            matchingDomains.add(domainResult)
    
    return matchingDomains

## Read each line from a file as an individual domain.
proc readDomainsFromFile(file: File): seq[string] =
    var topLevelDomains: seq[string]

    while not file.endOfFile():
        let line = file.readLine()
        topLevelDomains.add(line)

    return topLevelDomains

#[ Convert a sequence into an HTML <DIV> tag.

    Each element is turned into a span, which is prefixed by it's index in the
    sequence.
]#
proc makeDivFromList(list: seq, divStyle: string): string =
    var resultString = fmt"""<div style="{divStyle}">"""

    for i, item in list:
        var itemString = "<span>#"
        itemString.addInt(i + 1)
        itemString.add("  ")
        itemString.add(toString(item))
        itemString.add("</span>")

        resultString.add(itemString)

    resultString.add("</div>")

    return resultString

#[ A (very naive) sanitisation method to produce only alphabetic queries.

    Note: Of course, URLs can support a number of symbols (with encoding)
    including Chinese or Japanese characters, Arabic symbols, etc., but I'm not
    interested in building the requisite support infrastructure for that here.
    This is a fun side project to learn Nim, not one to understand URL encoding
    and Unicode.
]#
proc santiseQuery(query: string): string =
    var sanitisedString = ""

    for letter in query:
        if letter in Letters:
            sanitisedString.add(letter)
    return sanitisedString

#[ Default 404 response.

    Responded with when the user has gone off track and no other behaviour is
    defined.
]#
proc misdirect(req: Request) {.async.} =
    await req.respond(Http404, """
    <html>
    <body>
    <h1>You're lost, aren't you?</h1>
    <p><a href="/">Go home; you're drunk.</a></p>
    </body>
    </html>
    """)

#[ Default response for "/" route.

    The "homepage" of the service.
]#
proc index(req: Request) {.async.} =
    await req.respond(Http200, """
    <html>
        <body style="display:grid; justify-items: center;">
        <h1>domainator</h1>
        <p style="margin-top: 0px; margin-bottom: 32px;">hack domains.</p>
        <div class="search">
            <form action="/search" method="get">
                <input type="text" name="domain" class='search-text' placeholder="notthebees">
                <input type="submit" value="Submit">
            </form>
        </div>
        </body>
    </html>
    """)

#[ Handles the "/search" route.

    Responds to search requests for domain hacks.

    *Note:* This is "unsafe" because each async thread accesses the global
    variable TOP_LEVEL_DOMAINS. I'm interested in finding an alternative to this
    but that should not require reading the file while handling a request.
]#
proc search(req: Request, query: string) {.async, gcsafe.} =
    const divStyle = r"""display: grid; justify-items: start; padding:25px; width: 30vw;"""

    # Get input search term and santitise it.
    let keyword = split(query, "=")[0]
    let value = santiseQuery(split(query, "=")[1])
    if keyword != "domain" or value == "":
        await misdirect(req)

    # Get domains which match the term
    let domains = getMatchesForPhrase(value, TOP_LEVEL_DOMAINS)
    var messageBody: string

    if len(domains) != 0:
        messageBody = makeDivFromList(domains, divStyle)
    else:
        # No domains match; display a friendly error message
        messageBody = fmt"""<div style="{divStyle}">Hmmm... couldn't find anything for that term.</span>"""

    await req.respond(Http200, fmt"""
    <html>
    <body style="display:grid; justify-items: center;">
    <h1>results</h1>
    <em>"{value}"</em>
    <br />
    {messageBody}
    <br />
    <p><a href="/" style="color: black; cursor: default;">search again</a></p>
    </html>
    </body>
    """)

#[ HTTP request entry point; delegates routing.

    Determines what process should respond to a request based on the request
    method (GET, POST, etc), and URL path.
]#
proc cb(req: Request) {.async.} =
    if req.reqMethod == HttpGet and req.url.path == "/":
        await index(req)
    elif req.reqMethod == HttpGet and req.url.path == "/search":
        await search(req, req.url.query)
    else:
        await misdirect(req)

## Handle the SIGINT interrupt (or "Control+C").
proc sigintHandler() {.noconv.} =
    cursorBackward(2) # Removes ^C from output
    echo "Shutting down..."
    quit 0

# Read the top level domains into memory at startup to avoid disk I/O during a
# request.
let DOMAIN_FILE = open("topLevelDomains.txt")
TOP_LEVEL_DOMAINS = readDomainsFromFile(DOMAIN_FILE)
DOMAIN_FILE.close()

setControlCHook(sigintHandler)

const port = 8080
echo fmt"""Listening on port {port}..."""
asyncCheck newAsyncHttpServer().serve(Port(port), cb)
runForever()
