# domainator-nim

It's [Domainator](https://github.com/phildenhoff/domainator), but written in Nim.

## Purpose

Domainator is a "domain hacking" tool; it receives an input query and returns back a list of valid URLs which, when put together, form the query again in natural language.

For example, if you want to start selling Apples as "Cool Apples" then you might search "coolapples" and get back this list of potential URLs.

1. cool.app/les
2. cool.apple/s
3. coolappl.es
4. coo.la/pples
5. coolap.pl/es

Are all of those domains already sold? Almost certainly! But -- maybe with this you can finally snag the URL that isn't!

## Building

**Prerequisites:** Nim

Once Nim is installed, you can run the following command and you should be able to build from source. However, this has only been tested on MacOS X 10.14.5, so your mileage may vary.

```bash
nim c domainator.nim
```

You'll likely see a Warning about `TOP_LEVEL_DOMAINS`. I'm aware of it. If you can think of a fix for it - let me know!
