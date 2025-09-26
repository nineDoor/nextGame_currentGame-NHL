## Name: nextGame-currentGame(NHL).widget 
## Destination App: Übersicht
## Created: 21.Jan.2022
## Updaded: 26.Sept.2025
## Author: Woody Neilson
###
NextGame_CurrentGame-NHL WIdget
--------------------------
This widget displays the schedule for your favourite NHL team.
- It finds the next upcoming game and shows the matchup and time.
- When a game is live, it automatically switches to a live scoreboard with period, time remaining, score, and SOG.
- Styling changes based on game status (Live, Critical, Intermission).


USER SETTINGS
-------------
Change your favouriteTeamAbbrev to your team's three-letter code.
Change position on screen 
###
favouriteTeamAbbrev = "TOR"
positionTop = "20px"
positionRight = "20px"
###
TEAM ABBREVIATIONS
------------------
Anaheim Ducks        = ANA
Boston Bruins        = BOS
Buffalo Sabres       = BUF
Calgary Flames       = CGY
Carolina Hurricanes  = CAR
Chicago Blackhawks   = CHI
Colorado Avalanche   = COL
Columbus Blue Jackets= CBJ
Dallas Stars         = DAL
Detroit Red Wings    = DET
Edmonton Oilers      = EDM
Florida Panthers     = FLA
Los Angeles Kings    = LAK
Minnesota Wild       = MIN
Montréal Canadiens   = MTL
Nashville Predators  = NSH
New Jersey Devils    = NJD
New York Islanders   = NYI
New York Rangers     = NYR
Ottawa Senators      = OTT
Philadelphia Flyers  = PHI
Pittsburgh Penguins  = PIT
San Jose Sharks      = SJS
Seattle Kraken       = SEA
St. Louis Blues      = STL
Tampa Bay Lightning  = TBL
Toronto Maple Leafs  = TOR
Utah Mammoth         = UTA
Vancouver Canucks    = VAN
Vegas Golden Knights = VGK
Washington Capitals  = WSH
Winnipeg Jets        = WPG
###

###
AUTO-DETECT SEASON
------------------
Determines the current NHL season automatically (e.g., 20242025).
###
today = new Date()
year  = today.getFullYear()
month = today.getMonth() + 1
season = if month >= 9 then parseInt("#{year}#{year+1}") else parseInt("#{year-1}#{year}")

teamAbbreviation = favouriteTeamAbbrev + "/"


###
HELPER: Format UTC to Local Time
--------------------------------
Converts a UTC timestamp from the API into a localized 12-hour format (e.g., "7:00pm").
###
formatGameTime = (utcTime) ->
  startDate = new Date(utcTime)
  options = { hour: 'numeric', minute: '2-digit', hour12: true }
  return startDate.toLocaleTimeString('en-US', options).toLowerCase().replace(' ', '')


###
WIDGET CONFIG
-------------
###
refreshFrequency: 15000 # Start with a 20-second refresh

command: (callback) ->
  # Use a proxy to avoid CORS issues, common for Übersicht widgets
  proxy  = "http://127.0.0.1:41417/"
  server = "https://api-web.nhle.com/v1/club-schedule-season/"
  path   = teamAbbreviation + season
  $.get "#{proxy}#{server}#{path}", (json) ->
    callback null, json
  

render: (jsonData) ->
  # --- 1. INITIAL SETUP ---
  games = jsonData.games
  now   = new Date()
  proxy = "http://127.0.0.1:41417/"
  gameToShow = null
  landingData = null

  # --- 2. CATEGORIZE GAMES ---
  todaysGames = []
  futureGames = []
  nowStr = now.toDateString()

  for g in games
    gameDate = new Date(g.startTimeUTC)
    if gameDate.toDateString() == nowStr
      todaysGames.push g
    else if gameDate > now
      futureGames.push g

  # --- 3. FIND THE CORRECT GAME TO DISPLAY (REFACTORED LOGIC) ---
  # This new logic correctly prioritizes which game to show.

  # Priority 1 & 2: Find a game today (LIVE/CRIT > PRE/FUT)
  if todaysGames.length > 0
    liveGame = null
    liveLanding = null
    preGame = null
    preLanding = null

    for g in todaysGames
      landingUrl = "https://api-web.nhle.com/v1/gamecenter/#{g.id}/landing"
      contextTmp = undefined
      $.ajax
        url: proxy + landingUrl
        async: false
        dataType: 'json'
        success: (json) -> contextTmp = json

      if contextTmp?
        status = contextTmp.gameState
        if status == "LIVE" or status == "CRIT"
          # Highest priority: a live game. Grab it and stop searching.
          liveGame = g
          liveLanding = contextTmp
          break
        else if (status == "PRE" or status == "FUT") and !preGame?
          # A game scheduled for later today. Keep it in case no game is live.
          preGame = g
          preLanding = contextTmp

    # After checking all of today's games, decide which one to use
    if liveGame?
      gameToShow = liveGame
      landingData = liveLanding
    else if preGame?
      gameToShow = preGame
      landingData = preLanding
  # Priority 3: If no suitable game today (they are all FINAL/OFF), find the next future game.
  if !gameToShow? and futureGames.length > 0
    gameToShow = futureGames[0]

  # --- 4. HANDLE NO-GAME SCENARIO ---
  if !gameToShow?
    return "<table class='noGames'><tr><td>No upcoming games found</td></tr></table>"

  # --- 5. ENSURE WE HAVE LANDING DATA FOR THE SELECTED GAME ---
  # If we selected a future game, its data wasn't fetched in the loop above.
  if !landingData?
    landingUrl = "https://api-web.nhle.com/v1/gamecenter/#{gameToShow.id}/landing"
    $.ajax
      url: proxy + landingUrl
      async: false
      dataType: 'json'
      success: (json) -> landingData = json

  if !landingData?
    return "<table class='noGames'><tr><td>Could not load game data</td></tr></table>"

  # --- 6. PREPARE DATA FOR RENDERING ---
  status = landingData.gameState
  aLogo  = "<img src='#{landingData.awayTeam.logo}'/>"
  hLogo  = "<img src='#{landingData.homeTeam.logo}'/>"
  aTeam  = landingData.awayTeam.placeName.default + " " + landingData.awayTeam.commonName.default
  hTeam  = landingData.homeTeam.placeName.default  + " " + landingData.homeTeam.commonName.default
  aScore = landingData.awayTeam.score
  hScore = landingData.homeTeam.score
  aRec   = landingData.awayTeam.record
  hRec   = landingData.homeTeam.record
  favIconSVG = """
    <svg class="fav-team-icon" viewBox="0 0 14 8"><path d="M6.66669 0L6.00002 1H5.00002V0H4.75669C2.51335 0 0.623352 1.83667 0.666685 4.07667C0.710019 6.25 2.48335 8 4.66669 8C5.92002 8 7.03668 7.42333 7.77002 6.52333C8.64002 5.45333 9.78335 4.64333 11.0934 4.22L13.3334 3.5V0H6.66669ZM4.66669 5.85333C3.64335 5.85333 2.81335 5.02333 2.81335 4C2.81335 2.97667 3.64335 2.14667 4.66669 2.14667C5.69002 2.14667 6.52002 2.97667 6.52002 4C6.52002 5.02333 5.69002 5.85333 4.66669 5.85333Z"></path></svg>
  """
  # --- 7. ADAPTIVE REFRESH FREQUENCY ---
  if status == "LIVE" or status == "CRIT"
    @refreshFrequency = 15000 # Refresh every 15 seconds for live games
  else
    @refreshFrequency = 300000 # Refresh every 5 minutes for future games

  # --- 8. RENDER BASED ON GAME STATE ---

  # --- A) FUTURE / PRE-GAME ---
  if status == "FUT" or status == "PRE"
    gameTime = formatGameTime(gameToShow.startTimeUTC)
    gameDateStr = ""
    gd = new Date(gameToShow.startTimeUTC)
    
    todayStart = new Date(); todayStart.setHours(0,0,0,0)
    tomorrowStart = new Date(todayStart); tomorrowStart.setDate(todayStart.getDate() + 1)
    weekAhead = new Date(todayStart); weekAhead.setDate(todayStart.getDate() + 7)

    if gd.toDateString() == now.toDateString()
      gameDateStr = "Today "
    else if gd.toDateString() == new Date(now.getTime() + 86400000).toDateString()
        gameDateStr = "Tomorrow "
    else if gd < weekAhead
      gameDateStr = gd.toLocaleDateString('en-US', { weekday: 'long' }) + " "
    else
      gameDateStr = gd.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' }) + " "
      
    return """
      <table class='data'>
        <tr>
          <td class='logo' rowspan='2'>#{aLogo}</td>
          <td class='TeamName'>#{aTeam}</td>
        </tr>
        <tr><td class='record'>#{aRec}</td></tr>
        <tr>
          <td class='logo' rowspan='2'>#{hLogo}</td>
          <td class='TeamName'>#{hTeam}</td>
        </tr>
        <tr><td class='record'>#{hRec}</td></tr>
        <tr>
          <td colspan='2' class='dayAndTime'>#{gameDateStr}#{gameTime}</td>
        </tr>
      </table>
    """

  # --- B) LIVE / CRITICAL GAME ---
  else if status == "LIVE" or status == "CRIT"
    aSOG = landingData.awayTeam.sog
    hSOG = landingData.homeTeam.sog
    aSit = ""
    hSit = ""
    situationStr = ""
    hasSituation = false # Flag to track if there's any active situation

    # Power Play / Game Situation info
    if landingData.situation?
      hasSituation = true
      awayStrength = landingData.situation.awayTeam.strength
      homeStrength = landingData.situation.homeTeam.strength
      
      # Logic to ensure display is always greater#-ON-lesser#
      if awayStrength > homeStrength
        situationStr = "#{awayStrength}-ON-#{homeStrength}"
      else
        situationStr = "#{homeStrength}-ON-#{awayStrength}"
        
      # Append time remaining only if it exists (not present for EN)
      if landingData.situation.timeRemaining?
        situationStr += " | #{landingData.situation.timeRemaining}"

      if landingData.situation.awayTeam.situationDescriptions?
        aSit = landingData.situation.awayTeam.situationDescriptions[0]
      if landingData.situation.homeTeam.situationDescriptions?
        hSit = landingData.situation.homeTeam.situationDescriptions[0]

    # Period / Intermission logic
    periodNum = landingData.periodDescriptor?.number ? 0
    inIntermission = landingData.clock?.inIntermission
    timeRem = landingData.clock?.timeRemaining or ""
    period = "—"
    periodClass = "period" # Default to green

    if inIntermission
      period = switch periodNum
        when 1 then "1st INT"
        when 2 then "2nd INT"
        else "INT"
      periodClass = "intermission" # Grey background
    else
      period = switch periodNum
        when 1 then "1st"
        when 2 then "2nd"
        when 3 then "3rd"
        when 4 then "OT"
        when 5 then "SO"
        else "—"
      if status == "CRIT" or hasSituation
        periodClass = "crit" # Red background

    return """
      <table class='data'>
        <tr>
          <td class='logo' rowspan='2'>#{aLogo}</td>
          <td class='TeamName'>#{aTeam}</td>
          <td class='Score' rowspan='2'>#{aScore}</td>
        </tr>
        <tr>
          <td class='sog'>
            SOG: #{aSOG}#{ if aSit then " <span class='pp'>#{aSit}</span>" else "" }
          </td>
        </tr>
        <tr>
          <td class='logo' rowspan='2'>#{hLogo}</td>
          <td class='TeamName'>#{hTeam}</td>
          <td class='Score' rowspan='2'>#{hScore}</td>
        </tr>
        <tr>
          <td class='sog'>
            SOG: #{hSOG}#{ if hSit then " <span class='pp'>#{hSit}</span>" else "" }
          </td>
        </tr>
        <tr class='#{periodClass}'>
          <td class='gameSituation#{ if situationStr then " active" else "" }'></td>
          <td class='gameSituation#{ if situationStr then " active" else "" }'>#{situationStr}</td>
          <td class='period-and-time'>
            <span class='period-text'>#{period}</span><span class='time-text'>#{timeRem}</span>
          </td>
        </tr>
      </table>
    """

  # --- C) Otherwise (e.g., should not happen if logic is correct) ---
  else
    return "<table class='noGames'><tr><td>No game info</td></tr></table>"

###
STYLES
------
###
style: """
  top: #{positionTop}
  right: #{positionRight}
  color: black
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif
  font-size: 15px
  
  table
    min-width: 360px
    border-collapse: collapse
    background: rgba(255, 255, 255, 0.9)
    border: 1px solid #ccc
    border-radius: 8px
    box-shadow: 0 4px 12px rgba(0,0,0,0.1)
    overflow: hidden /* Ensures border-radius applies to child elements */

  table.data tr:first-child td.logo,
  table.data tr:first-child td.TeamName
    padding-top: 8px;

  td
    padding: 4px 8px
    white-space: nowrap
    vertical-align: middle
    border: none

  .logo 
    width: 44px;
    padding: 0 4px;       /* equal space both sides */
    text-align: center;   /* logo centered in its cell */
  
  .logo img 
    max-height: 42px;
    height: 42px;
    width: auto;

  .TeamName
    font-size: 20px
    font-weight: 600
    text-align: left

  .Score
    font-size: 28px
    font-weight: 700
    text-align: right
    width: 60px
    padding-right: 12px

  .record, .sog
    font-size: 13px
    color: #555
    text-align: left
    padding-top: 0
    
  .pp
    color: #E51C01 /* A slightly less jarring red */
    font-weight: 600
    margin-left: 6px

  /* --- Bottom Row: Future --- */
  .dayAndTime
    font-size: 16px
    text-align: right
    color: #333
    padding: 4px
    background: #f0f0f0
    border-bottom-left-radius: 8px
    border-bottom-right-radius: 8px

  /* --- Bottom Row: Live --- */
  .period, .crit
    color: white
    font-weight: 400
    text-align: center
  .intermission
    color: black
    font-weight: 400
    text-align: center
  .period td, .crit td, .intermission td
    padding-top: 1px
    padding-bottom: 1px

  .period
    background: #10750E /* Green */
  .crit
    background: #E51C01 /* Red */
  .intermission
    background: #E0E0E0 /* Light Grey */

  .gameSituation
    text-align: right
    font-size: 13px
    color: inherit /* Inherits black from the row */
    
  /* This style applies ONLY when a power play is active */
  .gameSituation.active
    background: white !important
    color: #E51C01 !important
    font-weight: 700
    border-radius: 4px
    margin-left: 4px
    padding: 2px 6px
  
  .period-and-time
    text-align: right
    padding-right: 6px
    
  .period-text
    font-weight: 600
    margin-right: 8px

  .time-text
    font-weight: 600

  .noGames
    padding: 16px
    text-align: center
    font-size: 16px
    color: #444
"""

