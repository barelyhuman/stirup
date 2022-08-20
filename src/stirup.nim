import osproc
import system/io
import std/[parsecfg, os, parseopt]

proc parseConfig(confPath: string): Config =
  var configDef = loadConfig(confPath)
  return configDef

type
  StirupConfig* = object
    configPath, user, host, port: string
    definitions: Config

proc loadConfig*(sc: var StirupConfig) =
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

proc execScript(sc: var StirupConfig) =
  var toExecute = sc.definitions.getSectionValue("actions", "execute")
  var p = startProcess("ssh", args = [sc.getHostUrl(), sc.getPortFlag(),
      readFile(toExecute)], options = {poUsePath, poParentStreams})
  doAssert p.waitForExit == 0

proc parseFlags(sc: var StirupConfig, kind: CmdLineKind, key: string, val: string) =
  case kind
    of cmdEnd: return
    # left as a separate case if I add something later
    of cmdLongOption, cmdShortOption: return
    of cmdArgument:
      sc.configPath = key
  if len(sc.configPath) == 0:
    sc.configPath = "./stirup.ini"


proc main() =
  var flagParser = initOptParser()
  var config: StirupConfig
  for kind, key, val in flagParser.getopt():
    config.parseFlags(kind, key, val)

  config.loadConfig()
  config.ping()
  config.execScript()


when isMainModule:
  main()
