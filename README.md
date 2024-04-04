# Contentful Roku

BrightScript Contentful SDK

## Installation

```bash
npm i contentful-roku
```

## Usage

```brightscript
' @import /components/libs/ContentfulSDK.brs from contentful-roku

sub init()
  m._contentful = ContentfulSDK({
    accessToken: "<My_Contentful_Access_Token>",
    baseUrl: "http://cdn.contentful.com", ' default value
    environment: "master", ' default value
    space: "<My_Contentful_Space_ID>",
  })

  m._contentful.getSpace().then(onDataReceived)
end sub

sub onDataReceived(contentfulSpaceData as Object)
  print contentfulSpaceData
end sub
```
