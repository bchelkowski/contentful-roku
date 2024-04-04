' @import /components/ArrayUtils.brs from @dazn/kopytko-utils
' @import /components/getProperty.brs from @dazn/kopytko-utils
' @import /components/getType.brs from @dazn/kopytko-utils
' @import /components/promise/Promise.brs from @dazn/kopytko-utils
' @import /components/uuid.brs from @dazn/kopytko-utils

function ContentfulSDK(config = {} as Object, options = {} as Object) as Object
  prototype = {}

  prototype._arrayUtils = ArrayUtils()
  prototype._config = {}
  prototype._deviceInfo = CreateObject("roDeviceInfo")
  prototype._options = { withAllLocales: false }
  prototype._requests = {}

  _constructor = function (context as Object, config = {} as Object, options = {} as Object) as Object
    if (config.accessToken = Invalid OR config.accessToken = "")
      print "Contentful - Missing config - accessToken"

      return Invalid
    end if

    if (config.space = Invalid OR config.space = "")
      print "Contentful - Missing config - space"

      return Invalid
    end if

    defaultConfig = {
      baseUrl: "https://cdn.contentful.com",
      environment: "master",
    }
    context._config = {}
    context._config.append(defaultConfig)
    context._config.append(config)

    if (NOT context._config.doesExist("headers")) then context._config.headers = {}
    context._config.headers.append({
      "Content-Type": "application/vnd.contentful.delivery.v1+json",
      "X-Contentful-User-Agent": context._getContentfulUserAgent(context._config),
    })

    if (options.withAllLocales <> Invalid) then context._options.withAllLocales = options.withAllLocales

    return context
  end function

  prototype.createAssetKey = function (expiresAt as LongInteger) as Object
    return m._fetch({
      baseUrl: m._getBaseUrl("environment"),
      data: { expiresAt: expiresAt },
      method: "POST",
      path: "asset_keys",
    })
  end function

  prototype.fetchAsset = function (id as String, queryParams = {} as Object) as Object
    if (m._options.withAllLocales) then queryParams.locale = "*"
  
    return m._fetch({
      baseUrl: m._getBaseUrl("environment"),
      path: ["assets", id].join("/"),
      queryParams: queryParams,
    })
  end function

  prototype.fetchAssets = function (id as String, queryParams = {} as Object) as Object
    if (m._options.withAllLocales) then queryParams.locale = "*"
  
    return m._fetch({
      baseUrl: m._getBaseUrl("environment"),
      path: "assets",
      queryParams: queryParams,
    })
  end function

  prototype.fetchContentType = function (id as String) as Object
    return m._fetch({
      baseUrl: m._getBaseUrl("environment"),
      path: ["content_types", id].join("/"),
    })
  end function

  prototype.fetchContentTypes = function (queryParams = {} as Object) as Object
    return m._fetch({
      baseUrl: m._getBaseUrl("environment"),
      path: "content_types",
      queryParams: queryParams,
    })
  end function

  prototype.fetchEntry = function (id as String, queryParams = {} as Object) as Object
    if (m._options.withAllLocales) then queryParams.locale = "*"
  
    queryParams.["sys.id"] = id
  
    return m._fetch({
      baseUrl: m._getBaseUrl("environment"),
      path: "entries",
      queryParams: queryParams,
    })
  end function

  prototype.fetchEntries = function (queryParams = {} as Object) as Object
    if (m._options.withAllLocales) then queryParams.locale = "*"
  
    return m._fetch({
      baseUrl: m._getBaseUrl("environment"),
      path: "entries",
      queryParams: queryParams,
    })
  end function

  prototype.fetchLocales = function (queryParams = {} as Object) as Object
    return m._fetch({
      baseUrl: m._getBaseUrl("environment"),
      path: "locales",
      queryParams: queryParams,
    })
  end function

  prototype.fetchSpace = function () as Object
    return m._fetch({
      baseUrl: m._getBaseUrl("space"),
      path: "",
    })
  end function

  prototype.fetchTag = function (id as String) as Object
    return m._fetch({
      baseUrl: m._getBaseUrl("environment"),
      path: ["tags", id].join("/"),
    })
  end function

  prototype.fetchTags = function (queryParams = {} as Object) as Object
    return m._fetch({
      baseUrl: m._getBaseUrl("environment"),
      path: "tags",
      queryParams: queryParams,
    })
  end function

  prototype._fetch = function (options = {} as Object) as Object
    fetchOptions = {}
    fetchOptions.append(m._config)
    fetchOptions.append(options)
    id = uuid()

    if (fetchOptions.doesExist("queryParams"))
      fetchOptions.queryParams = m._normalizeSelect(fetchOptions.queryParams)
      fetchOptions.queryParams = m._normalizeQueryParams(fetchOptions.queryParams)
    end if

    m._requests[id] = {
      promise: Promise(),
      request: CreateObject("roSGNode", "ContentfulRequest"),
    }
    m._requests[id].request.id = id
    m._requests[id].request.setFields(fetchOptions)
    m._requests[id].request.observeFieldScoped("result", "contentfulSDK_onRequestResult")
    m._requests[id].request.control = "run"

    return m._requests[id].promise
  end function

  prototype._getBaseUrl = function (context = "space" as String) as String
    baseUrl = m._config.baseURL

    if (m._config.doesExist("space")) then baseUrl = [baseUrl, "spaces", m._config.space].join("/")
    if (context = "space") then return baseUrl
  
    return [baseUrl, "environments", m._config.environment].join("/")
  end function

  prototype._getContentfulUserAgent = function (config = {} as Object) as String
    userAgentParts = []
  
    application = getProperty(config, "application", "")
    if (application <> "") then userAgentParts.push(application)
  
    integration = getProperty(config, "integration", "")
    if (integration <> "") then userAgentParts.push(integration)
  
    userAgentParts.push("sdk contentful.roku")
    userAgentParts.push("platform roku")
    userAgentParts.push("os " + m._getOSVersion())
  
    return userAgentParts.join("; ")
  end function

  prototype._getOSVersion = function () as String
    OSVersion = m._deviceInfo.getOSVersion()
  
    return OSVersion.major + "." + OSVersion.minor + "." + OSVersion.revision + "." + OSVersion.build
  end function

  prototype._normalizeQueryParams = function (queryParms as Object) as Object
    normalizedQueryParams = {}

    for each queryParmKey in queryParms
      if (getType(queryParms[queryParmKey]) = "roArray")
        normalizedQueryParams[queryParmKey] = []

        for each item in queryParms[queryParmKey]
          if (GetInterface(item, "ifToStr") <> Invalid) then normalizedQueryParams[queryParmKey].push(item.toStr().trim())
        end for

        normalizedQueryParams[queryParmKey] = normalizedQueryParams[queryParmKey].join(",")
      else
        normalizedQueryParams[queryParmKey] = queryParms[queryParmKey]
      end if
    end for

    return normalizedQueryParams
  end function

  prototype._normalizeSelect = function (queryParms as Object) as Object
    if (NOT queryParms.doesExist("select")) then return queryParms

    selectParts = []
    selectType = getType(queryParms.select)
    if (selectType = "roArray")
      selectParts = queryParms.select
    else if (selectType = "roString")
      selectParts = m._arrayUtils.map(queryParms.select.split(","), function (part as String) as String
        return part.trim()
      end function)
    end if

    if (m._arrayUtils.contains(selectParts, "sys")) then return queryParms
    if (NOT m._arrayUtils.contains(selectParts, "sys.id")) then selectParts.push("sys.id")
    if (NOT m._arrayUtils.contains(selectParts, "sys.type")) then selectParts.push("sys.type")

    normalizedQueryParams = {}
    normalizedQueryParams.append(queryParms)
    normalizedQueryParams.select = selectParts.join(",")

    return normalizedQueryParams
  end function

  m["$$ContentfulSDK"] = _constructor(prototype, config, options)

  return m["$$ContentfulSDK"]
end function

sub contentfulSDK_onRequestResult(event as Object)
  result = event.getData()

  if (result.id = Invalid OR m["$$ContentfulSDK"]._requests[result.id] = Invalid) then return

  if (result.data <> Invalid)
    m["$$ContentfulSDK"]._requests[result.id].promise.resolve(result.data)
  else
    m["$$ContentfulSDK"]._requests[result.id].promise.reject()
  end if

  m["$$ContentfulSDK"]._requests[result.id].request.unobserveFieldScoped("result")
  m["$$ContentfulSDK"]._requests.delete(result.id)
end sub
