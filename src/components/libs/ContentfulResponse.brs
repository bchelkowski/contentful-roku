' @import /components/ArrayUtils.brs from @dazn/kopytko-utils
' @import /components/getProperty.brs from @dazn/kopytko-utils
' @import /components/getType.brs from @dazn/kopytko-utils

function ContentfulResponse(response as String) as Object
  prototype = {}

  prototype._arrayUtils = ArrayUtils()
  prototype._response = Invalid

  _constructor = function (context as Object, response as String) as Object
    context._response = ParseJSON(response)

    return context
  end function

  prototype.parse = function (options = { removeUnresolved: false } as Object) as Object
    if (m._response = Invalid OR m._response.items = Invalid) then return []

    m._parseOptions = options
    allEntries = []
    allIncludes = []
    includes = getProperty(m._response, "includes", {})

    for each includeKey in includes
      for each item in includes[includeKey]
        allIncludes.push(item)
      end for
    end for

    allEntries.append(m._response.items)
    allEntries.append(allIncludes)
    allEntries = m._arrayUtils.filter(allEntries, function (entity = {} as Object) as Boolean
      return entity.sys <> Invalid
    end function)

    m._entityMap = {}
    for each entity in allEntries
      keys = m._makeEntityMapKeys(entity.sys)
      for each key in keys
        m._entityMap[key] = entity
      end for
    end for

    for each item in allEntries
      entryObject = m._makeEntryObject(item)

      m._walkMutate(entryObject)
    end for

    m._entityMap = Invalid
    m._parseOptions = Invalid
  
    return m._response
  end function

  prototype._predicate = function (item as Object) as Boolean
    return m._isLink(item) OR m._isResourceLink(item)
  end function

  prototype._mutator = function (link as Object) as Object
    return m._normalizeLink(link)
  end function

  prototype._cleanUpLinks = function (input as Object) as Object
    if (getType(input) = "roArray")
      return m._arrayUtils.filter(input, function (item as Object) as Boolean
        return (getType(item) = "roAssociativeArray") AND (NOT item.isEmpty())
      end function)
    end if

    for each key in input
      if ((getType(input[key]) = "roAssociativeArray" AND input[key].isEmpty())) then input.delete(key)
    end for

    return input
  end function

  prototype._getIdsFromUrn = function (urn as String) as Object
    regExp = CreateObject("roRegex", ".*:spaces\/([^/]+)(?:\/environments\/([^/]+))?\/entries\/([^/]+)$", "")
  
    if (NOT regExp.isMatch(urn)) then return { spaceId: "", environmentId: "", entryId: "" }

    match = regExp.match(urn)
    environmentId = "master"
    if (match[2] <> "") then environmentId = match[2]
  
    return { spaceId: match[1], environmentId: environmentId, entryId: match[3] }
  end function

  prototype._getResolvedLink = function (link as Object) as Object
    if (m._isResourceLink(link))
      ids = m._getIdsFromUrn(getProperty(link, ["sys", "urn"], ""))
      extractedLinkType = getProperty(link, ["sys", "linkType"], "").split(":")[1]
      resolvedLink = m._lookupInEntityMap({
        linkType: extractedLinkType,
        entryId: ids.entryId,
        environmentId: ids.environmentId,
        spaceId: ids.spaceId,
      })

      if (resolvedLink = Invalid) then return {}
  
      return resolvedLink
    end if

    resolvedLink = m._lookupInEntityMap({
      linkType: getProperty(link, ["sys", "linkType"], ""),
      entryId: getProperty(link, ["sys", "id"], ""),
    })

    if (resolvedLink = Invalid) then return {}
  
    return resolvedLink
  end function

  prototype._isLink = function (obj as Object) as Boolean
    return getProperty(obj, ["sys", "type"], "") = "Link"
  end function

  prototype._isResourceLink = function (obj as Object) as Boolean
    return getProperty(obj, ["sys", "type"], "") = "ResourceLink"
  end function

  prototype._lookupInEntityMap = function (linkData as Object) as Object
    if (m._entityMap = Invalid OR linkData = Invalid) then return Invalid

    baseInEntityMap = [linkData.linkType, linkData.entryId].join("!")
    environmentId = getProperty(linkData, "environmentId", "")
    spaceId = getProperty(linkData, "spaceId", "")
  
    if (spaceId <> "" AND environmentId <> "")
      return m._entityMap[[spaceId, environmentId, baseEntityMapKey].join("!")]
    end if
  
    return m._entityMap[baseInEntityMap]
  end function

  prototype._makeEntityMapKeys = function (sys = {} as Object) as Object
    baseEntityMapKey = [getProperty(sys, "type", ""), getProperty(sys, "id", "")].join("!")

    if (sys.space <> Invalid AND sys.environment <> Invalid)
      return [
        baseEntityMapKey,
        [getProperty(sys, ["space", "sys", "id"], ""), getProperty(sys, ["environment", "sys", "id"], ""), baseEntityMapKey].join("!"),
      ]
    end if
  
    return [baseEntityMapKey]
  end function

  prototype._makeEntryObject = function (item as Object) as Object
    if (getType(m._parseOptions.itemEntryPoints) <> "roArray") then return item
  
    entryObject = {}
    entryPoints = m._arrayUtils.filter(item.keys(), function (key as String) as Boolean
      return m._arrayUtils.find(m._parseOptions.itemEntryPoints, key) <> Invalid
    end function)

    for each entryPoint in entryPoints
      entryObject[entryPoint] = item[entryPoint]
    end for

    return entryObject
  end function

  prototype._normalizeLink = function (link as Object) as Object
    resolvedLink = m._getResolvedLink(link)

    if (resolvedLink.isEmpty() AND NOT m._parseOptions.removeUnresolved) then return link

    return resolvedLink
  end function

  prototype._walkMutate = function (input as Object) as Object
    if (m._predicate(input)) then return m._mutator(input)

    if (getType(input) = "roArray")
      for index = 0 to input.count() - 1
        if (input[index] <> Invalid) then input[index] = m._walkMutate(input[index])
      end for

      if (m._parseOptions.removeUnresolved) then input = m._cleanUpLinks(input)
    else if (getType(input) = "roAssociativeArray")
      for each key in input
        if (input[key] <> Invalid) then input[key] = m._walkMutate(input[key])
      end for

      if (m._parseOptions.removeUnresolved) then input = m._cleanUpLinks(input)
    end if

    return input
  end function

  return _constructor(prototype, response)
end function
