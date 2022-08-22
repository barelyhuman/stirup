import osproc
import system/io
import std/[parsecfg, os, parseopt]

type
  ExecutionStage = enum
    prePrepare, postPrepare, preExecute, postExecute
  Artifact* = object
    path: string
    stage: ExecutionStage
    archive: bool
  StirupConfig* = object
    configPath, user, host, port: string
    definitions: Config
    runPrepare: bool
    artifactCount: int
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

proc getPortFlag(sc: var StirupConfig): string =
  return "-p "&sc.port

proc ping(sc: var StirupConfig) =
  var p = startProcess("ssh", args = [sc.getHostUrl(), sc.getPortFlag(),
      "echo 'ping'"], options = {poUsePath, poParentStreams})
  doAssert p.waitForExit == 0

proc readFile(filepath: string): string =
  var fd = open(filepath)
  return fd.readAll()


proc execPrepare(sc: var StirupConfig) =
  var prepareScript = sc.definitions.getSectionValue("actions", "prepare")
  var prepareTask = startProcess("ssh", args = [sc.getHostUrl(),
      sc.getPortFlag(),
    readFile(prepareScript)], options = {poUsePath, poParentStreams})
  doAssert prepareTask.waitForExit == 0

proc execScript(sc: var StirupConfig) =
  var toExecute = sc.definitions.getSectionValue("actions", "execute")
  if toExecute != "":
    var execTask = startProcess("ssh", args = [sc.getHostUrl(), sc.getPortFlag(),
      readFile(toExecute)], options = {poUsePath, poParentStreams})
    doAssert execTask.waitForExit == 0


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
    if len(pathValue) == 0:
      break

    var executionStage = sc.definitions.getSectionValue(sectionKey, "stage")
    var artifact = Artifact()
    artifact.path = pathValue

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

  sc.artifactCount = artifactCount


proc main() =
  var flagParser = initOptParser()
  var config: StirupConfig
  var run = true
  for kind, key, val in flagParser.getopt():
    run = config.parseFlags(kind, key, val)

  if not run:
    return

  config.loadConfig()
  config.loadArtifactDetails()
  config.ping()
  if config.runPrepare:
    config.execPrepare()
  config.execScript()


when isMainModule:
  main()
