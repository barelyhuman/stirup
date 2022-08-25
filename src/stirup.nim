import osproc
import system/io
import std/[parsecfg, os, parseopt]

type
  ExecutionStage = enum
    prePrepare, postPrepare, preExecute, postExecute
  Artifact* = object
    path, destination: string
    stage: ExecutionStage
    archive: bool
  StirupConfig* = object
    configPath, user, host, port: string
    definitions: Config
    runPrepare: bool
    artifacts: seq[Artifact]

proc printHelp() =
  echo """
  stirup 
  
  USAGE
  -----
    
    $ stirup 
    # ^ will look for configuration at ./stirup.ini, or 
    
    $ stirup ./path/to/config.ini

  --prepare, p    Run the prepare script from the configuration 
                  ( actions -> prepare ) before running the execute script
  --help, h       Display this help menu
  """

proc parseConfig(confPath: string): Config =
  try:
    var configDef = loadConfig(confPath)
    return configDef
  except:
    let e = getCurrentExceptionMsg()
    printHelp()
    quit "Error: failed to open the config file, make sure you have one\n\nfailure msg: " & e, 1

proc readFile(filepath: string): string =
  var fd = open(filepath)
  var data = fd.readAll()
  fd.close()
  return data

proc scp(source: string, destination: string, host: string, port: string) =
  echo [port, source, host&":"&destination]
  var exec = startProcess("scp", args = [port, source, host&":"&destination],
      options = {poUsePath, poParentStreams})
  var exitCode = exec.waitForExit
  if exitCode != 0:
    quit "exited with code:" & $exitCode

proc sshExec(host: string, port: string, script: string = "",
    ping: bool = false) =
  var args: seq[string];

  args.add(host)
  args.add("-p"&port)

  if ping:
    args.add("echo '[stirup-ssh] Ping'")
  elif len(script) > 0:
    args.add(readFile(script))

  var exec = startProcess("ssh", args = args, options = {poUsePath,
      poParentStreams})
  var exitCode = exec.waitForExit
  if exitCode != 0:
    quit "exited with code:" & $exitCode

proc loadConfig*(sc: var StirupConfig) =
  # default path for config if none was provided
  if len(sc.configPath) == 0:
    sc.configPath = "./stirup.ini"

  var configDefs = parseConfig(sc.configPath)
  setCurrentDir(parentDir(sc.configPath))
  sc.definitions = configDefs
  sc.user = configDefs.getSectionValue("connection", "user")
  sc.host = configDefs.getSectionValue("connection", "host")
  sc.port = configDefs.getSectionValue("connection", "port")

proc getHostUrl(sc: var StirupConfig): string =
  return sc.user&"@"&sc.host

proc ping(sc: var StirupConfig) =
  sshExec(ping = true, host = sc.getHostUrl(), port = sc.port)

proc execPrepare(sc: var StirupConfig) =
  var prepareScript = sc.definitions.getSectionValue("actions", "prepare")

  if prepareScript == "":
    return

  sshExec(host = sc.getHostUrl(), port = sc.port, script = prepareScript)

proc execScript(sc: var StirupConfig) =
  var toExecute = sc.definitions.getSectionValue("actions", "execute")

  if toExecute == "":
    return

  sshExec(host = sc.getHostUrl(), port = sc.port, script = toExecute)


proc parseFlags(sc: var StirupConfig, kind: CmdLineKind, key: string,
    val: string): bool =
  case kind
    of cmdEnd: return true
    of cmdLongOption, cmdShortOption:
      if key == "help" or key == "h":
        printHelp()
        return;
      if key == "prepare" or key == "p":
        sc.runPrepare = true
    of cmdArgument:
      sc.configPath = key
  return true

proc loadArtifactDetails(sc: var StirupConfig) =
  var artifactCount = 1

  while true:
    var sectionKey = "artifact_" & $artifactCount
    var pathValue = sc.definitions.getSectionValue(sectionKey, "path")

    var destPathValue = sc.definitions.getSectionValue(sectionKey, "destination")
    if len(pathValue) == 0 or len(destPathValue) == 0:
      break

    var executionStage = sc.definitions.getSectionValue(sectionKey, "stage")
    var artifact = Artifact()
    artifact.path = pathValue
    artifact.destination = destPathValue

    case executionStage
      of "pre_prepare":
        artifact.stage = prePrepare
      of "post_prepare":
        artifact.stage = postPrepare
      of "pre_execute":
        artifact.stage = preExecute
      of "post_execute":
        artifact.stage = postExecute

    var createArchive = sc.definitions.getSectionValue(sectionKey, "archive")
    artifact.archive = false
    if createArchive == "true":
      artifact.archive = true

    sc.artifacts.add(artifact)

    artifactCount+=1

proc getSCPPortFlag(sc: var StirupConfig): string =
  return "-P "&sc.port


proc copyPrePrepareArtifacts(sc: var StirupConfig) =
  let hostUrl = sc.getHostUrl()
  let portFlag = sc.getSCPPortFlag()
  for i in countup(0, sc.artifacts.len-1):
    echo "i:" & $i
    let artifact = sc.artifacts[i]

    if artifact.stage != prePrepare:
      continue

    scp(artifact.path, artifact.destination, hostUrl, portFlag)


proc copyPostPrepareArtifacts(sc: var StirupConfig) =
  let hostUrl = sc.getHostUrl()
  let portFlag = sc.getSCPPortFlag()

  for i in countup(0, sc.artifacts.len-1):
    let artifact = sc.artifacts[i]
    if artifact.stage != postPrepare:
      continue

    scp(artifact.path, artifact.destination, hostUrl, portFlag)

proc copyPreExecuteArtifacts(sc: var StirupConfig) =
  let hostUrl = sc.getHostUrl()
  let portFlag = sc.getSCPPortFlag()

  for i in countup(0, sc.artifacts.len-1):
    let artifact = sc.artifacts[i]
    if artifact.stage != preExecute:
      continue

    scp(artifact.path, artifact.destination, hostUrl, portFlag)

proc copyPostExecuteArtifacts(sc: var StirupConfig) =
  let hostUrl = sc.getHostUrl()
  let portFlag = sc.getSCPPortFlag()

  for i in countup(0, sc.artifacts.len-1):
    let artifact = sc.artifacts[i]
    if artifact.stage != postExecute:
      continue

    scp(artifact.path, artifact.destination, hostUrl, portFlag)

proc main() =
  var flagParser = initOptParser()
  var config: StirupConfig
  var run = true
  for kind, key, val in flagParser.getopt():
    run = config.parseFlags(kind, key, val)

  if not run:
    return

  echo "[stirup-local] loading config"
  config.loadConfig()
  config.loadArtifactDetails()
  echo "[stirup-local] pinging ssh server"
  config.ping()
  if config.runPrepare:
    config.copyPrePrepareArtifacts()
    echo "[stirup-local] executing prepare"
    config.execPrepare()
    config.copyPostPrepareArtifacts()

  config.copyPreExecuteArtifacts()
  echo "[stirup-local] executing script"
  config.execScript()
  config.copyPostExecuteArtifacts()


when isMainModule:
  main()
