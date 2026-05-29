"use strict"


$id = -> document.getElementById it
$q  = -> document.querySelector  it
$cc = -> document.getElementsByClassName it


contains = (haystack, needle) ->
    !!~haystack.indexOf needle


format02d = (n) ->
    "0#{n}".slice -2


formatTime = (minutes) ->
    "#{format02d Math.floor minutes / 60}:#{format02d minutes % 60}"


after = (seconds, action) ->
    setTimeout action, seconds * 1000


every = (seconds, action) ->
    setInterval action, seconds * 1000


timeIt = (title, action) ->
    console.time title
    try
        action!
    finally
        console.timeEnd title


decompress =
    if window.TextDecoder?
        # Faster.
        (data) -> new TextDecoder!decode pako.inflate data
    else
        (data) -> pako.inflate data, to: \string


getStep = ->
    try +/\d+/.exec($q '#m_fight_log .block_h .block_title' .textContent).0
    catch => 0


setProgress = (value) !->
    try $q '#turn_pbar .p_bar div' .style.width = "#{value}%"


progressTimer = 0


runProgressTimer = (ago, stepDuration) !->
    percentsPerMillisecond = 0.1 / stepDuration
    basePoint = Date.now!
    if progressTimer
        if window.cancelAnimationFrame?
            cancelAnimationFrame progressTimer
        else
            clearInterval progressTimer
        progressTimer := 0

    ago = Math.min ago * percentsPerMillisecond * 1000, 100
    setProgress ago

    updateProgress = !->
        if (progress = ago + (Date.now! - basePoint) * percentsPerMillisecond) < 100 - 1e-5
            setProgress progress
            yes
        else
            setProgress 100
            no

    if window.requestAnimationFrame?
        tick = !->
            if updateProgress!
                progressTimer := requestAnimationFrame tick
            else
                progressTimer := 0
        progressTimer := requestAnimationFrame tick
    else
        progressTimer := every 0.25s, !->
            unless updateProgress!
                clearInterval progressTimer
                progressTimer := 0


normalizeDuelType = (duelType) ->
    return "" unless duelType?
    normalized = ("#{duelType}".toLowerCase!)
    if normalized == \boss || normalized == \dungeon || normalized == \sail
        normalized
    else
        ""


getOrCreateArenaColumn = (arena, className) ->
    col = arena.getElementsByClassName className .0
    unless col?
        col = document.createElement \div
        col.className = "#{className} group_wrapper"
        arena.appendChild col
    col


clearNode = (node) !->
    while node.firstChild?
        node.removeChild node.firstChild


escapeHtml = (value) ->
    "#{if value? then value else ''}"
        .replace /&/g, '&amp;'
        .replace /</g, '&lt;'
        .replace />/g, '&gt;'
        .replace /"/g, '&quot;'
        .replace /'/g, '&#39;'


upsertBossBlock = (opponentHtml) ->
    bossBlock = $id \s_boss
    if opponentHtml? && opponentHtml.trim!.length
        if bossBlock?
            bossBlock.outerHTML = opponentHtml
            bossBlock = $id \s_boss
        else
            wrapper = document.createElement \div
            wrapper.innerHTML = opponentHtml
            bossBlock = wrapper.firstElementChild

    unless bossBlock?
        bossBlock = document.createElement \div
        bossBlock.id = \s_boss
        bossBlock.className = \block
        bossBlock.innerHTML = "
            <div class=\"block_h\"><h2 class=\"block_title\">Босс</h2></div>
            <div class=\"block_content\"><div class=\"line\">Нет данных о боссе</div></div>
        "
    bossBlock


ensureArenaLayout = (duelType, opponent) !->
    arena = $id \arena_columns
    pageWrapper = $q \.page_wrapper
    return unless arena? && pageWrapper?

    alliesBlock = $id \alls
    mapBlock = $id \s_map
    chronicleBlock = $id \m_fight_log
    return unless alliesBlock? && mapBlock? && chronicleBlock?
    bossBlock = upsertBossBlock opponent

    smallCol = getOrCreateArenaColumn arena, \m_small_col
    largeCol = getOrCreateArenaColumn arena, \m_large_col
    bossCol = arena.getElementsByClassName \m_boss_opp_col .0

    pageWrapper.classList.toggle \layout-boss, duelType == \boss
    pageWrapper.classList.toggle \layout-dungeon, duelType == \dungeon

    switch duelType
    | \boss
        bossCol := getOrCreateArenaColumn arena, \m_boss_opp_col
        clearNode smallCol
        clearNode largeCol
        clearNode bossCol
        smallCol.appendChild alliesBlock
        largeCol.appendChild chronicleBlock
        mapBlock.style.display = \none
        bossCol.appendChild mapBlock
        bossCol.appendChild bossBlock
    | \dungeon
        clearNode smallCol
        clearNode largeCol
        smallCol.appendChild alliesBlock
        mapBlock.style.display = ""
        largeCol.appendChild mapBlock
        chronicleWrapper = document.createElement \div
        chronicleWrapper.className = "m_chronicle_wrapper group_wrapper"
        chronicleWrapper.appendChild chronicleBlock
        largeCol.appendChild chronicleWrapper
        arena.removeChild bossCol if bossCol? && bossCol.parentNode == arena
    | _
        clearNode smallCol
        clearNode largeCol
        smallCol.appendChild alliesBlock
        smallCol.appendChild chronicleBlock
        mapBlock.style.display = ""
        largeCol.appendChild mapBlock
        arena.removeChild bossCol if bossCol? && bossCol.parentNode == arena


updatePage = ({allies, map, chronicle, opponent, clientData, duelType}) !->
    currentDuelType = normalizeDuelType if duelType? then duelType else window.gDuelType
    $id \alls .outerHTML = allies

    if $id \map_wrap
        $id \map_wrap
            scrollValue = ..scrollLeft / ..scrollWidth
        $id \s_map .outerHTML = map
        $id \map_wrap
            ..scrollLeft = scrollValue * ..scrollWidth
    else
        $id \s_map .outerHTML = map

    $id \m_fight_log .outerHTML = chronicle

    window.gReporterClientData = clientData
    if currentDuelType.length
        window.gDuelType = currentDuelType
    ensureArenaLayout currentDuelType, opponent


checksumCache = { }

calcSymbolChecksum = (c) ->
    return that if checksumCache[c]?

    canvas = document.createElement \canvas
    return 0 unless canvas.getContext? && (context = canvas.getContext \2d)? && context.fillText?
    context
        ..textBaseline = \top
        ..font = "32px Arial"
        ..fillText c, 0px 0px
        img = ..getImageData 0px 0px, 32px 32px

    return 0 unless img?
    result = 0; [result += .. for img.data]
    checksumCache[c] = result


shouldUseCustomFont =
    if !window.MSStream? && /iP[ao]d|iPhone/.test navigator.userAgent
        -> no
    else if \
        (navigator.userAgent `contains` \Firefox && ! navigator.userAgent `contains` \Macintosh) ||
        !(undrawableChecksum = calcSymbolChecksum '\uFFFF')
        -> yes
    else
        -> it && ("↖↗←→↙↘↑↓" `contains` it || calcSymbolChecksum(it) == undrawableChecksum)


toggleHovered = !-> @toggle \hovered # Called on a `DOMTokenList`.

postprocessPage = !->
    # Localize the time.
    offset = new Date!getTimezoneOffset!
    for node in $cc \d_time
    when (//(\d*) \s* : \s* (\d*)//.exec node.textContent)?
        node.textContent = formatTime (+that.1 * 60 + +that.2 - offset) %% (24 * 60)

    # Change font on the map where needed.
    for tile in $cc \tile
    when (text = tile.getElementsByTagName \text .0)? && shouldUseCustomFont text.textContent.trim!
        tile.classList.add \em_font

    # Apply a class to an ark when its owner's name is hovered.
    mapBlock = $id \s_map
    for line in $id \alls .getElementsByClassName \oppl
        nameNode = line.getElementsByClassName \opp_n .0
        if mapBlock.getElementsByClassName "pl#{parseInt nameNode.textContent}" .0?
            toggleHovered.bind that.classList
                line.addEventListener \mouseenter, ..
                line.addEventListener \mouseleave, ..


getBootData = ->
    root = $id \hero_block
    unless root?
        return
            updatedAgo: 0
            stepDuration: 18

    updatedAgo = parseFloat root.dataset.updatedAgo
    stepDuration = parseFloat root.dataset.stepDuration
    duelType = root.dataset.duelType

    unless isFinite updatedAgo
        updatedAgo = 0
    unless isFinite(stepDuration) && stepDuration > 1e-5
        stepDuration = 18

    if duelType? && duelType.length
        window.gDuelType = duelType

    {updatedAgo, stepDuration}


socket = null
retryEvery = 3s
retryCount = 0


disconnect = !->
    if socket?
        socket.onclose = null
        socket.close!
        socket := null


connect = !->
    if socket?
        console.warn "An old socket still existed"
        disconnect!

    socket := new WebSocket do
        "
        #{if location.protocol == "https:" then "wss" else "ws"}://
        #{location.host}#{location.pathname}/ws#{location.search}
        "
    socket.onclose = !->
        socket := null
        after 3s, connect
    justConnected = 1 # true
    socket.binaryType = \arraybuffer
    socket.onmessage = (msg) !->
        response = timeIt "Decompression", -> JSON.parse decompress msg.data
        if response.stayHere
            # The log is being deleted from the server, and we are asked to try fetching it later.
            disconnect!
            {retryEvery, retryCount} := response
            after response.retryAfter, connect
        else if (url = response.redirect)?
            if --retryCount > 0
                # We were asked to ignore redirections for a while.
                disconnect!
                after retryEvery, connect
            else
                location.replace url # `disconnect` is called from the `unload` handler.
        else if response.step > getStep! || normalizeDuelType(response.duelType) != normalizeDuelType(window.gDuelType)
            retryCount := 0 # Reset the counter.
            updatePage response
            postprocessPage!
            runProgressTimer justConnected && response.ago, response.stepDuration

        justConnected := 0 # false


# Chrome does not support closing a WebSocket connection with a code other than 1000 or 3000...4999,
# so we can't use 1001 Going Away.
addEventListener \unload, disconnect

<-! addEventListener \DOMContentLoaded

boot = getBootData!
postprocessPage!
runProgressTimer boot.updatedAgo, boot.stepDuration
connect!
