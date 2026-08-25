import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model
import "I18n.js" as I18n

Panel {
  id: root
  moduleName: "iaeluk.omastatus"
  ipcTarget: "iaeluk.omastatus"

  property var hotSensors: ["_memory_usage_", "_processor_usage_", "__network-rx_max__"]

  function syncHotSensors() {
    const dflt = ["_memory_usage_", "_processor_usage_", "__network-rx_max__"]
    let v = setting("hotSensors", dflt)
    let arr
    try { arr = Array.from(v) } catch(e) { arr = null }
    hotSensors = (arr && arr.length > 0) ? arr.slice(0, 20) : dflt
  }
  readonly property int updateTime: Math.max(1, Number(setting("updateTime", 2)) || 2)
  readonly property bool useHigherPrecision: setting("useHigherPrecision", false) === true
  readonly property bool alphabetize: setting("alphabetize", true) !== false
  readonly property bool hideZeros: setting("hideZeros", false) === true
  readonly property bool hideIcons: setting("hideIcons", false) === true
  readonly property bool fixedWidths: setting("fixedWidths", true) !== false
  readonly property int unit: Number(setting("unit", 0)) || 0
  readonly property bool showTemperature: setting("showTemperature", true) !== false
  readonly property bool showVoltage: setting("showVoltage", false) === true
  readonly property bool showFan: setting("showFan", true) !== false
  readonly property bool showMemory: setting("showMemory", true) !== false
  readonly property bool showProcessor: setting("showProcessor", true) !== false
  readonly property bool showSystem: setting("showSystem", true) !== false
  readonly property bool showNetwork: setting("showNetwork", true) !== false
  readonly property bool showStorage: setting("showStorage", true) !== false
  readonly property bool showBattery: setting("showBattery", false) === true
  readonly property bool showGpu: setting("showGpu", true) !== false
  readonly property string storagePath: String(setting("storagePath", "/") || "/")
  readonly property int memoryMeasurement: Number(setting("memoryMeasurement", 1)) || 1
  readonly property int storageMeasurement: Number(setting("storageMeasurement", 1)) || 1
  readonly property int batterySlot: Number(setting("batterySlot", 0)) || 0
  readonly property string monitorCmd: String(setting("monitorCmd", "gnome-system-monitor") || "gnome-system-monitor")
  readonly property bool includeStaticInfo: setting("includeStaticInfo", false) === true
  readonly property bool includeStaticGpuInfo: setting("includeStaticGpuInfo", false) === true
  readonly property int iconStyle: Number(setting("iconStyle", 0)) || 0
  readonly property int networkSpeedFormat: Number(setting("networkSpeedFormat", 0)) || 0
  readonly property int networkSpeedUnit: Number(setting("networkSpeedUnit", 0)) || 0
  readonly property bool includePublicIp: setting("includePublicIp", true) !== false

  property var sensorMap: ({})
  property var sensorList: []
  property var groupMap: ({})
  property var hotMap: ({})
  property var widths: ({})
  property bool firstPollDone: false
  property double lastPollTime: 0
  property var prevCpu: ({})
  property var prevNet: ({})
  property var prevDisk: ({})
  property var netSpeeds: ({})
  property double dwell: 2
  property real maxBarWidth: 0

  function settingsObj(){
    return {
      useHigherPrecision: root.useHigherPrecision,
      memoryMeasurement: root.memoryMeasurement,
      storageMeasurement: root.storageMeasurement,
      unit: root.unit,
      networkSpeedFormat: root.networkSpeedFormat,
      networkSpeedUnit: root.networkSpeedUnit
    }
  }

  function iconFor(type, label){
    if (root.hideIcons) return ""
    if (type.startsWith("temperature")) return ""
    if (type==="voltage") return "󰚥"
    if (type==="fan") return ""
    if (type==="memory" || type==="memory-group") return ""
    if (type==="processor" || type==="processor-stat" || type==="processor-group") return ""
    if (type==="system" || type==="system-group") return ""
    if (type==="network" || type.startsWith("network-")) return type==="network-tx" ? "" : type==="network-rx" ? "" : ""
    if (type==="storage" || type==="storage-group") return "󰋊"
    if (type.startsWith("battery")) return ""
    if (type.startsWith("gpu")) return "󰢮"
    return "●"
  }

  function isGroupVisible(group){
    if(group==="temperature") return root.showTemperature
    if(group==="voltage") return root.showVoltage
    if(group==="fan") return root.showFan
    if(group==="memory") return root.showMemory
    if(group==="processor") return root.showProcessor
    if(group==="system") return root.showSystem
    if(group==="network") return root.showNetwork
    if(group==="storage") return root.showStorage
    if(group==="battery") return root.showBattery
    if(group==="gpu") return root.showGpu
    return true
  }

  property var expandedGroups: ({})
  function isExpanded(group){ return expandedGroups[group] === true }
  function toggleGroup(group){
    let e = Object.assign({}, expandedGroups)
    e[group] = !isExpanded(group)
    expandedGroups = e
  }
  property bool orderingMode: false
  function moveHotSensor(from, to){
    if(from<0 || to<0 || from>=hotSensors.length || to>=hotSensors.length) return
    let list = hotSensors.slice()
    const item = list.splice(from,1)[0]
    list.splice(to,0,item)
    const ns = Object.assign({}, settings, {hotSensors: list})
    if(bar && bar.shell) bar.shell.updateEntryInline(moduleName, ns)
    else settings = ns
  }

  function sensorKey(type,label){
    return Model.sensorKeyFromTypeLabel(type,label)
  }

  function updateHotMap(){
    const map={}
    const s=settingsObj()
    for(let k of root.hotSensors){
      const entry=root.sensorMap[k]
      if(entry){
        map[k]=entry.text
      } else if(k==="__network-rx_max__" || k==="__network-tx_max__"){
        const dir=k.includes("tx")?"tx":"rx"
        let sum=0
        for(let key in root.sensorMap){
          if(key.includes("_"+dir+"_") || key.startsWith("__network-"+dir)){
            const e=root.sensorMap[key]
            if(e && e.rawSpeed!==undefined) sum+=e.rawSpeed
          }
        }
        const agg=root.netSpeeds[dir]||0
        const leg=Model.legible(agg, "speed", s, "network-"+dir, k)
        map[k]=leg.text
      } else if(k==="_default_icon_"){
        map[k]=""
      } else {
        map[k]="…"
      }
    }
    root.hotMap=map
  }

  function setUpdateTime(v){
    const nv=Math.max(1, Math.min(60, Number(v)||2))
    const ns=Object.assign({}, root.settings, {updateTime: nv})
    if(root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, ns)
    else root.settings=ns
  }

  function toggleHotSensor(key){
    let list=root.hotSensors.slice()
    const idx=list.indexOf(key)
    if(idx>=0){
      list.splice(idx,1)
    } else {
      list.push(key)
    }
    if(list.length===0){
      list=["_default_icon_"]
    } else {
      const di=list.indexOf("_default_icon_")
      if(di>=0) list.splice(di,1)
    }
    const newSettings=Object.assign({}, root.settings, {hotSensors:list})
    if(root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, newSettings)
    else root.settings=newSettings
  }

  function refresh(){
    if(!collectProc.running) collectProc.running=true
  }

  function processCollectOutput(text){
    const now=Date.now()/1000
    const prev= root.lastPollTime||now
    root.dwell = Math.max(0.5, now - prev)
    root.lastPollTime=now
    const cappedLines=String(text||"").split("\n").slice(0,500)
    const lines=cappedLines
    const s=settingsObj()
    let newMap={}
    let newGroups={}
    let cpuCurr={}
    let netCurr={}
    for(let line of lines){
      line=line.trim()
      if(!line) continue
      let obj
      try{ obj=JSON.parse(line)} catch(e){ continue }
      const label=String(obj.label||"")
      const type=String(obj.type||"")
      const format=String(obj.format||"")
      let value=obj.value
      const grp=Model.groupForType(type)
      if(!root.isGroupVisible(grp) && grp!=="gpu" && !type.includes("processor-stat") && !type.startsWith("network")){
        if(!["processor-stat","storage"].includes(type) && grp!=="network") {
        }
      }
      if(type==="processor-stat"){
        cpuCurr[label]=Number(value)
        continue
      }
      if((type==="network-rx" || type==="network-tx") && format==="storage"){
        netCurr[label]=Number(value)
        const key=sensorKey(type,label)
        const leg=Model.legible(Number(value), "storage", s, type, key)
        if(root.hideZeros && Number(value)===0) continue
        newMap[key]={label, value:Number(value), type, format:"storage", text:leg.text, style:leg.style, key, icon: iconFor(type,label)}
        if(!newGroups[grp]) newGroups[grp]=[]
        newGroups[grp].push(key)
        const prevVal=root.prevNet[label]
        if(prevVal!==undefined && root.firstPollDone){
          const speed=(Number(value)-prevVal)/root.dwell
          const skey=label
          const sleg=Model.legible(speed, "speed", s, type, key)
          newMap[key].rawSpeed=speed
          newMap[key].speedText=sleg.text
          newMap[key].speedStyle=sleg.style
          if(!root.netSpeeds[type.split("-")[1]]) root.netSpeeds[type.split("-")[1]]={}
        }
        continue
      }
      if(root.hideZeros && (type==="temperature"||type==="voltage") && Number(value)===0) continue
      const key=sensorKey(type,label)
      let leg
      if(format==="string" || format==="" ){
        leg={text:String(value), style:""}
      } else {
        const num=Number(value)
        leg=Model.legible(isFinite(num)?num:value, format, s, type, key)
      }
      newMap[key]={label, value, type, format, text:leg.text, style:leg.style, key, icon: iconFor(type,label)}
      const g=Model.groupForType(type)
      if(!newGroups[g]) newGroups[g]=[]
      if(newGroups[g].indexOf(key)===-1) newGroups[g].push(key)
    }
    const cores=Object.keys(cpuCurr).length-1
    for(let cpu in cpuCurr){
      const curr=cpuCurr[cpu]
      const prev=root.prevCpu[cpu]
      if(prev!==undefined && root.firstPollDone){
        const pct=Model.processorPercent(prev,curr,root.dwell, cores>0?cores:1)
        if(pct!==null){
          const label=cpu==="cpu"?"Usage": ("Core "+cpu.replace("cpu",""))
          const type="processor"
          const key=cpu==="cpu" ? "_processor_usage_" : sensorKey(type,label)
          const leg=Model.legible(pct, "percent", s, type, key)
          if(!(root.hideZeros && pct===0)){
            newMap[key]={label, value:pct, type, format:"percent", text:leg.text, style:leg.style, key, icon: iconFor(type,label)}
            const g="processor"
            if(!newGroups[g]) newGroups[g]=[]
            if(newGroups[g].indexOf(key)===-1) newGroups[g].push(key)
            if(cpu==="cpu"){
              const gkey="_processor_processor_"
              newMap["_processor_processor_"]={label:"processor", value:pct, type:"processor-group", format:"percent", text:leg.text, style:leg.style, key:"_processor_processor_", icon: iconFor("processor-group","")}
            }
          }
        }
      }
    }
    let rxSum=0, txSum=0
    for(let k in newMap){
      if(newMap[k].rawSpeed!==undefined){
        if(k.includes("_rx_") || k.startsWith("__network-rx")) rxSum+=newMap[k].rawSpeed
        if(k.includes("_tx_") || k.startsWith("__network-tx")) txSum+=newMap[k].rawSpeed
      }
    }
    root.netSpeeds["rx"]=rxSum
    root.netSpeeds["tx"]=txSum
    if(rxSum>0 || !root.hideZeros){
      const leg=Model.legible(rxSum, "speed", s, "network-rx", "__network-rx_max__")
      newMap["__network-rx_max__"]={label:"Device rx", value:rxSum, type:"network-rx", format:"speed", text:leg.text, style:leg.style, key:"__network-rx_max__", icon: iconFor("network-rx","")}
      if(!newGroups["network"]) newGroups["network"]=[]
      newGroups["network"].push("__network-rx_max__")
    }
    if(txSum>0 || !root.hideZeros){
      const leg=Model.legible(txSum, "speed", s, "network-tx", "__network-tx_max__")
      newMap["__network-tx_max__"]={label:"Device tx", value:txSum, type:"network-tx", format:"speed", text:leg.text, style:leg.style, key:"__network-tx_max__", icon: iconFor("network-tx","")}
      if(!newGroups["network"]) newGroups["network"]=[]
      newGroups["network"].push("__network-tx_max__")
    }

    const limitedMap={}; let c=0; for(let k in newMap){ if(c>=100) break; limitedMap[k]=newMap[k]; c++ }
    root.sensorMap=limitedMap
    let sorted=[]
    for(let g in newGroups){
      let arr=newGroups[g].slice()
      if(root.alphabetize){
        arr.sort((a,b)=>{
          const ea=newMap[a], eb=newMap[b]
          const la=ea ? ea.label : a
          const lb=eb ? eb.label : b
          return la.localeCompare(lb, undefined, {numeric:true, sensitivity:'base'})
        })
      }
      newGroups[g]=arr
      sorted=sorted.concat(arr)
    }
    root.groupMap=newGroups
    root.sensorList=sorted
    root.prevCpu=cpuCurr
    root.prevNet=netCurr
    root.firstPollDone=true
    updateHotMap()
  }

  onSettingsChanged: {
    syncHotSensors()
    refresh()
  }

  Component.onCompleted: {
    syncHotSensors()
    refresh()
  }

  onOpenedChanged: if(opened){ expandedGroups = ({}); orderingMode = false; refresh() }
  onHotSensorsChanged: { maxBarWidth = 0; updateHotMap() }
  onFixedWidthsChanged: maxBarWidth = 0

  Timer {
    id: pollTimer
    interval: root.updateTime*1000
    repeat: true
    running: true
    triggeredOnStart: false
    onTriggered: root.refresh()
  }

  Process {
    id: collectProc
    command: ["timeout", "4", "bash", Qt.resolvedUrl("helpers/collect.sh").toString().replace("file://",""), "--storage-path", root.storagePath, "--battery-slot", String(root.batterySlot)]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const capped = text.length > 256*1024 ? text.slice(0,256*1024) : text
        root.processCollectOutput(capped)
      }
    }
  }

  property string displayText: {
    root.hotSensors; root.hotMap; root.sensorMap; root.hideIcons
    return root.computeBarText()
  }

  function computeBarText(){
    if(root.hotSensors.length===0 || (root.hotSensors.length===1 && root.hotSensors[0]==="_default_icon_")) return ""
    let parts=[]
    for(let k of root.hotSensors){
      let v=root.hotMap[k]
      if(v===undefined) v="…"
      let entry=root.sensorMap[k]
      let icon=""
      if(!root.hideIcons){
        if(entry && entry.icon) icon=entry.icon+" "
        else if(k.includes("memory")) icon=" "
        else if(k.includes("system")) icon=" "
        else if(k.includes("storage")) icon="󰋊 "
        else if(k.includes("network")) icon=" "
        else if(k.includes("temperature")) icon=" "
        else if(k.includes("processor")) icon=" "
        else icon="● "
      }
      parts.push(icon+v)
    }
    const result = parts.join("  ")
    return result
  }

  Text {
    id: measureText
    visible: false
    text: root.displayText
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
    onImplicitWidthChanged: {
      if (root.fixedWidths) {
        if (implicitWidth > root.maxBarWidth) root.maxBarWidth = implicitWidth
      } else {
        root.maxBarWidth = implicitWidth
      }
    }
    onTextChanged: {
      if (implicitWidth > root.maxBarWidth && root.fixedWidths) root.maxBarWidth = implicitWidth
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    fontSize: Style.font.body
    horizontalMargin: 6
    verticalPadding: 6
    fixedWidth: root.fixedWidths && root.maxBarWidth > 0 ? root.maxBarWidth + Style.space(12) : -1
    onPressed: function(b){
      if(b===Qt.RightButton) root.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(col.implicitHeight, Style.space(600))

    ScrollView {
      anchors.fill: parent
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: ScrollBar.AlwaysOff
      Column {
        id: col
        width: parent.width
        spacing: Style.space(10)

        Item {
          width: parent.width
          height: Math.max(headerIcon.implicitHeight, statusColumn.implicitHeight, gearButton.implicitHeight)
          Text { id: headerIcon; text: "󰍹"; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.display; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
          Column {
            id: statusColumn
            anchors.left: headerIcon.right
            anchors.leftMargin: Style.space(8)
            anchors.right: gearButton.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text { text: I18n.t("OmaStatus"); color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.title; font.bold:true; width: parent.width; elide: Text.ElideRight }
            Row {
              spacing: Style.space(2)
              width: parent.width
              Text { text: I18n.tArgs("ATUALIZADO A CADA %1S  •  %2 SENSORES", root.updateTime, root.sensorList.length).toUpperCase(); color: Qt.darker(root.bar.foreground,1.4); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing:1; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: parent.width - Style.space(84) }
              Button {
                text: "−"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                horizontalPadding: Style.space(6)
                verticalPadding: Style.space(2)
                fontSize: Style.font.caption
                tooltipText: I18n.t("Diminuir intervalo")
                onClicked: root.setUpdateTime(Math.max(1, root.updateTime - 1))
              }
              Text {
                text: root.updateTime + "s"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                width: Style.space(28)
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
              }
              Button {
                text: "+"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                horizontalPadding: Style.space(6)
                verticalPadding: Style.space(2)
                fontSize: Style.font.caption
                tooltipText: I18n.t("Aumentar intervalo")
                onClicked: root.setUpdateTime(Math.min(60, root.updateTime + 1))
              }
            }
          }
          WidgetButton {
            id: gearButton
            text: root.orderingMode ? "✕" : ""
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            tooltipText: root.orderingMode ? I18n.t("Fechar ordenação") : I18n.t("Ordenar pinados")
            anchors.right: parent.right
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            fixedWidth: Style.space(18)
            fixedHeight: Style.space(18)
            horizontalMargin: 0
            verticalPadding: 0
            onPressed: root.orderingMode = !root.orderingMode
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Column {
          visible: root.orderingMode
          width: parent.width
          spacing: Style.space(6)

          PanelSectionHeader { text: I18n.t("ORDEM NA BARRA"); foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }

          Text {
            text: I18n.t("Use \u2191\u2193 para reordenar \u2014 X remove da barra")
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            width: parent.width
          }

                    Repeater {
            model: root.hotSensors
            delegate: Rectangle {
              required property string modelData
              required property int index
              property string skey: modelData
              property var entry: root.sensorMap[skey]
              width: col.width
              height: 28
              radius: Style.cornerRadius/2
              color: Util.alpha(root.bar.foreground, 0.06)
              border.color: Util.alpha(root.bar.foreground, 0.12)
              border.width: 1
              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(4)
                spacing: Style.space(4)
                Text { text: (index+1) + "."; color: Qt.darker(root.bar.foreground,1.2); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; width: Style.space(16); horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                Text { textFormat: Text.PlainText; maximumLineCount: 1; elide: Text.ElideRight; wrapMode: Text.NoWrap; text: entry ? entry.icon : "●"; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; width: Style.space(16); horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                Text { textFormat: Text.PlainText; maximumLineCount: 1; elide: Text.ElideRight; wrapMode: Text.NoWrap; text: entry ? I18n.sensorLabel(entry.label) : skey; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; width: parent.width - Style.space(16) - Style.space(16) - 70; anchors.verticalCenter: parent.verticalCenter }
                Button {
                  text: "↑"
                  enabled: index > 0
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  horizontalPadding: Style.space(4)
                  verticalPadding: Style.space(2)
                  fontSize: Style.font.caption
                  tooltipText: I18n.t("Mover para cima")
                  onClicked: root.moveHotSensor(index, index-1)
                }
                Button {
                  text: "↓"
                  enabled: index < root.hotSensors.length - 1
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  horizontalPadding: Style.space(4)
                  verticalPadding: Style.space(2)
                  fontSize: Style.font.caption
                  tooltipText: I18n.t("Mover para baixo")
                  onClicked: root.moveHotSensor(index, index+1)
                }
                Button {
                  text: "✕"
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  horizontalPadding: Style.space(4)
                  verticalPadding: Style.space(2)
                  fontSize: Style.font.caption
                  tooltipText: I18n.t("Remover da barra")
                  onClicked: root.toggleHotSensor(skey)
                }
              }
            }
          }
          PanelSeparator { foreground: root.bar.foreground }
        }

        Repeater {
          model: Object.keys(root.groupMap)
          delegate: Column {
            id: groupDelegate
            required property string modelData
            required property int index
            property string group: modelData
            visible: root.isGroupVisible(group)
            width: col.width
            spacing: Style.space(6)

            Rectangle {
              width: parent.width
              height: 28
              radius: Style.cornerRadius/2
              color: headerMouse.containsMouse ? Util.alpha(root.bar.foreground, 0.06) : "transparent"
              Item {
                anchors.fill: parent
                anchors.leftMargin: Style.space(4)
                anchors.rightMargin: Style.space(8)
                Row {
                  id: groupLabel
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)
                  Item {
                    width: Style.space(18)
                    height: Style.space(18)
                    anchors.verticalCenter: parent.verticalCenter
                    OpticalGlyph {
                      text: {
                        if(group==="temperature") return ""
                        if(group==="fan") return ""
                        if(group==="voltage") return "󰚥"
                        if(group==="memory") return ""
                        if(group==="processor") return ""
                        if(group==="system") return ""
                        if(group==="network") return ""
                        if(group==="storage") return "󰋊"
                        if(group==="battery") return ""
                        if(group.startsWith("gpu")) return "󰢮"
                        return "●"
                      }
                      fontFamily: root.bar.fontFamily
                      fontSize: Style.font.body
                      color: root.bar.foreground
                      anchors.centerIn: parent
                    }
                  }
                  Text {
                    text: {
                      if(group==="temperature") return I18n.t("Temperatura")
                      if(group==="fan") return I18n.t("Ventoinhas")
                      if(group==="voltage") return I18n.t("Voltagem")
                      if(group==="memory") return I18n.t("Memória")
                      if(group==="processor") return I18n.t("Processador")
                      if(group==="system") return I18n.t("Sistema")
                      if(group==="network") return I18n.t("Rede")
                      if(group==="storage") return I18n.t("Armazenamento")
                      if(group==="battery") return I18n.t("Bateria")
                      if(group.startsWith("gpu")) return I18n.t("GPU")
                      return group
                    }
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold:true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
                Text {
                  id: accordionIcon
                  text: root.isExpanded(group) ? "▾" : "▸"
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.body
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(18)
                  horizontalAlignment: Text.AlignHCenter
                }
                Text {
                  text: {
                    const arr=root.groupMap[group]
                    if(!arr||arr.length===0) return "—"
                    const k=arr[0]
                    const e=root.sensorMap[k]
                    return e? e.text : "No Data"
                  }
                  color: Qt.darker(root.bar.foreground,1.3)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  anchors.left: groupLabel.right
                  anchors.right: accordionIcon.left
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight
                  horizontalAlignment: Text.AlignRight
                }
              }
              MouseArea {
                id: headerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleGroup(group)
              }
            }

            Column {
              visible: root.isExpanded(group)
              width: parent.width
              spacing: 2
              Repeater {
                model: (root.groupMap[group] || []).slice(0,30)
                delegate: Rectangle {
                  required property string modelData
                  property string skey: modelData
                  property var entry: root.sensorMap[skey]
                  width: col.width
                  height: 28
                  radius: Style.cornerRadius/2
                  color: {
                    const checked = root.hotSensors.indexOf(skey)!==-1
                    if(checked) return Util.alpha(Color.accent, 0.15)
                    return mouse.containsMouse ? Util.alpha(root.bar.foreground,0.08) : "transparent"
                  }
                  border.color: root.hotSensors.indexOf(skey)!==-1 ? Color.accent : "transparent"
                  border.width: 1

                  Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(8)
                    anchors.right: checkBox.left
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(8)
                    Text { textFormat: Text.PlainText; maximumLineCount: 1; elide: Text.ElideRight; wrapMode: Text.NoWrap; text: entry ? entry.icon : "●"; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; width: Style.space(18); horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                    Text { textFormat: Text.PlainText; maximumLineCount: 1; elide: Text.ElideRight; wrapMode: Text.NoWrap; text: entry ? I18n.sensorLabel(entry.label) : skey; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; width: parent.width - Style.space(18) - Style.space(8) - valueText.width - Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                    Text {
                      id: valueText
                      textFormat: Text.PlainText
                      maximumLineCount: 1
                      elide: Text.ElideRight
                      wrapMode: Text.NoWrap
                      text: entry ? entry.text : "—"
                      color: {
                        if(entry && entry.style && entry.style.includes("rgb")){
                          const m=entry.style.match(/rgb\((\d+),\s*(\d+),\s*(\d+)\)/)
                          if(m) return Qt.rgba(m[1]/255,m[2]/255,m[3]/255,1)
                        }
                        return root.bar.foreground
                      }
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: root.hotSensors.indexOf(skey)!==-1
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }
                  Text {
                    id: checkBox
                    text: root.hotSensors.indexOf(skey)!==-1 ? "☑" : "☐"
                    color: root.bar.foreground
                    font.pixelSize: Style.font.body
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleHotSensor(skey)
                  }
                }
              }
            }
            PanelSeparator { foreground: root.bar.foreground; visible: groupDelegate.index < Object.keys(root.groupMap).length - 1 }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        RowLayout {
          width: parent.width
          spacing: Style.space(8)
          Button {
            text: I18n.t("Monitor do Sistema")
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            tooltipText: I18n.t("Abrir btop (monitor oficial do Omarchy)")
            onClicked: {
              Quickshell.execDetached(["omarchy-launch-or-focus-tui", "btop"])
              root.close()
            }
          }
          Item { Layout.fillWidth: true; height: 1 }
          Button {
            text: I18n.t("Atualizar")
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            tooltipText: I18n.t("Atualizar todos os sensores agora")
            onClicked: root.refresh()
          }
        }
      }
    }
  }
}