--[[--------------------------------------------------------------------
	Broker_PlayedTime
	DataBroker plugin to track played time across all your characters.
	Copyright (c) 2010-2016 Phanx <addons@phanx.net>. All rights reserved.
	http://www.wowinterface.com/downloads/info16711-BrokerPlayedTime.html
	https://mods.curse.com/addons/wow/broker-playedtime
	https://github.com/Phanx/Broker_PlayedTime
----------------------------------------------------------------------]]

local ADDON, L = ...

setmetatable(L, { __index = function(t, k)
	local v = tostring(k)
	t[k] = v
	return v
end })

-- THE REST OF THIS FILE IS AUTOMATICALLY GENERATED. SEE:
-- https://wow.curseforge.com/addons/broker-playedtime/localization/

------------------------------------------------------------------------
-- English
------------------------------------------------------------------------

local CURRENT_LOCALE = GetLocale()
if CURRENT_LOCALE == "enUS" then return end

------------------------------------------------------------------------
-- German
------------------------------------------------------------------------

if CURRENT_LOCALE == "deDE" then

L["Played Time"] = "Gespielte Zeit"
L["Right click for settings"] = "Rechtsklick für Einstellungen"
L["Total"] = "Gesamt"
L["Sorting"] = "Sortierung"
L["By played time"] = "Nach Zeit"
L["By played time this level"] = "Nach Zeit auf dieser Stufe"
L["By character name"] = "Nach Charaktername"
L["By character level"] = "Nach Charakterlevel"
L["Sorting of equal levels"] = "Sortierung gleicher Stufen"
L["Show character levels"] = "Charakterlevel anzeigen"
L["Show played time this level"] = "Gespielte Zeit auf dieser Stufe anzeigen"
L["Show class icons"] = "Klassensymbole anzeigen"
L["Show faction icons"] = "Fraktionssymbole anzeigen"
L["None"] = "Keine"
L["Group by factions"] = "Nach Fraktionen gruppiert"
L["Current realm only"] = "Nur aktuelles Realm"
L["Current character on top"] = "Aktueller Charakter oben"
L["Current character highlighted"] = "Aktueller Charakter mit Pfeil"
L["Time in hours (not days)"] = "Zeit in Stunden (nicht Tagen)"
L["Always show minutes also"] = "Immer auch Minuten anzeigen"
L["Remove character"] = "Charakter entfernen"
L["Broker icon text"] = "Broker Icontext"
L["Current character time"] = "Zeit des aktuellen Charakters"
L["Total time"] = "Gesamtzeit"

return end

------------------------------------------------------------------------
-- Spanish
------------------------------------------------------------------------

if CURRENT_LOCALE == "esES" then

L["Played Time"] = "Tiempo Jugado"
L["Right click for settings"] = "Clic derecho para ajustes"
L["Total"] = "Total"
L["Sorting"] = "Ordenación"
L["By played time"] = "Por tiempo jugado"
L["By played time this level"] = "Por tiempo jugado en este nivel"
L["By character name"] = "Por nombre del personaje"
L["By character level"] = "Por nivel del personaje"
L["Sorting of equal levels"] = "Ordenación de niveles iguales"
L["Show character levels"] = "Mostrar niveles de personaje"
L["Show played time this level"] = "Mostrar tiempo jugado en este nivel"
L["Show class icons"] = "Mostrar iconos de clase"
L["Show faction icons"] = "Mostrar iconos de facción"
L["None"] = "Ninguno"
L["Group by factions"] = "Agrupar por facciones"
L["Current realm only"] = "Solo reino actual"
L["Current character on top"] = "Personaje actual arriba"
L["Current character highlighted"] = "Personaje actual resaltado"
L["Time in hours (not days)"] = "Tiempo en horas (no días)"
L["Always show minutes also"] = "Mostrar siempre también los minutos"
L["Remove character"] = "Eliminar personaje"
L["Broker icon text"] = "Texto del icono de Broker"
L["Current character time"] = "Tiempo del personaje actual"
L["Total time"] = "Tiempo total"

return end

------------------------------------------------------------------------
-- Latin American Spanish
------------------------------------------------------------------------

if CURRENT_LOCALE == "esMX" then

L["Played Time"] = "Tiempo Jugado"
L["Right click for settings"] = "Clic derecho para ajustes"
L["Total"] = "Total"
L["Sorting"] = "Ordenación"
L["By played time"] = "Por tiempo jugado"
L["By played time this level"] = "Por tiempo jugado en este nivel"
L["By character name"] = "Por nombre del personaje"
L["By character level"] = "Por nivel del personaje"
L["Sorting of equal levels"] = "Ordenación de niveles iguales"
L["Show character levels"] = "Mostrar niveles de personaje"
L["Show played time this level"] = "Mostrar tiempo jugado en este nivel"
L["Show class icons"] = "Mostrar iconos de clase"
L["Show faction icons"] = "Mostrar iconos de facción"
L["None"] = "Ninguno"
L["Group by factions"] = "Agrupar por facciones"
L["Current realm only"] = "Solo reino actual"
L["Current character on top"] = "Personaje actual arriba"
L["Current character highlighted"] = "Personaje actual resaltado"
L["Time in hours (not days)"] = "Tiempo en horas (no días)"
L["Always show minutes also"] = "Mostrar siempre también los minutos"
L["Remove character"] = "Eliminar personaje"
L["Broker icon text"] = "Texto del icono de Broker"
L["Current character time"] = "Tiempo del personaje actual"
L["Total time"] = "Tiempo total"

return end

------------------------------------------------------------------------
-- French
------------------------------------------------------------------------

if CURRENT_LOCALE == "frFR" then

L["Played Time"] = "Temps de jeu"
L["Right click for settings"] = "Clic droit pour les paramètres"
L["Total"] = "Total"
L["Sorting"] = "Tri"
L["By played time"] = "Par temps de jeu"
L["By played time this level"] = "Par temps de jeu ce niveau"
L["By character name"] = "Par nom du personnage"
L["By character level"] = "Par niveau du personnage"
L["Sorting of equal levels"] = "Tri des niveaux égaux"
L["Show character levels"] = "Afficher les niveaux des personnages"
L["Show played time this level"] = "Afficher le temps de jeu ce niveau"
L["Show class icons"] = "Afficher les icônes de classe"
L["Show faction icons"] = "Afficher les icônes de faction"
L["None"] = "Aucun"
L["Group by factions"] = "Grouper par factions"
L["Current realm only"] = "Royaume actuel seulement"
L["Current character on top"] = "Personnage actuel en haut"
L["Current character highlighted"] = "Personnage actuel mis en évidence"
L["Time in hours (not days)"] = "Temps en heures (pas en jours)"
L["Always show minutes also"] = "Toujours afficher les minutes aussi"
L["Remove character"] = "Supprimer le personnage"
L["Broker icon text"] = "Texte de l'icône Broker"
L["Current character time"] = "Temps du personnage actuel"
L["Total time"] = "Temps total"

return end

------------------------------------------------------------------------
-- Italian
------------------------------------------------------------------------

if CURRENT_LOCALE == "itIT" then

L["Played Time"] = "Tempo di gioco"
L["Right click for settings"] = "Clic destro per impostazioni"
L["Total"] = "Totale"
L["Sorting"] = "Ordinamento"
L["By played time"] = "Per tempo di gioco"
L["By played time this level"] = "Per tempo di gioco in questo livello"
L["By character name"] = "Per nome del personaggio"
L["By character level"] = "Per livello del personaggio"
L["Sorting of equal levels"] = "Ordinamento di livelli uguali"
L["Show character levels"] = "Mostra livelli personaggio"
L["Show played time this level"] = "Mostra tempo di gioco in questo livello"
L["Show class icons"] = "Mostra icone di classe"
L["Show faction icons"] = "Mostra icone di fazione"
L["None"] = "Nessuno"
L["Group by factions"] = "Raggruppa per fazioni"
L["Current realm only"] = "Solo regno attuale"
L["Current character on top"] = "Personaggio attuale in alto"
L["Current character highlighted"] = "Personaggio attuale evidenziato"
L["Time in hours (not days)"] = "Tempo in ore (non giorni)"
L["Always show minutes also"] = "Mostra sempre anche i minuti"
L["Remove character"] = "Rimuovi personaggio"
L["Broker icon text"] = "Testo icona Broker"
L["Current character time"] = "Tempo personaggio attuale"
L["Total time"] = "Tempo totale"

return end

------------------------------------------------------------------------
-- Brazilian Portuguese
------------------------------------------------------------------------

if CURRENT_LOCALE == "ptBR" then

L["Played Time"] = "Tempo Jogado"
L["Right click for settings"] = "Clique com o botão direito para configurações"
L["Total"] = "Total"
L["Sorting"] = "Ordenação"
L["By played time"] = "Por tempo jogado"
L["By played time this level"] = "Por tempo jogado neste nível"
L["By character name"] = "Por nome do personagem"
L["By character level"] = "Por nível do personagem"
L["Sorting of equal levels"] = "Ordenação de níveis iguais"
L["Show character levels"] = "Mostrar níveis de personagem"
L["Show played time this level"] = "Mostrar tempo jogado neste nível"
L["Show class icons"] = "Mostrar ícones de classe"
L["Show faction icons"] = "Mostrar ícones de facção"
L["None"] = "Nenhum"
L["Group by factions"] = "Agrupar por facções"
L["Current realm only"] = "Apenas reino atual"
L["Current character on top"] = "Personagem atual no topo"
L["Current character highlighted"] = "Personagem atual destacado"
L["Time in hours (not days)"] = "Tempo em horas (não dias)"
L["Always show minutes also"] = "Sempre mostrar minutos também"
L["Remove character"] = "Remover personagem"
L["Broker icon text"] = "Texto do ícone do Broker"
L["Current character time"] = "Tempo do personagem atual"
L["Total time"] = "Tempo total"

return end

------------------------------------------------------------------------
-- Russian
------------------------------------------------------------------------

if CURRENT_LOCALE == "ruRU" then

L["Played Time"] = "Время игры"
L["Right click for settings"] = "Правый клик для настроек"
L["Total"] = "Всего"
L["Sorting"] = "Сортировка"
L["By played time"] = "По времени игры"
L["By played time this level"] = "По времени игры на этом уровне"
L["By character name"] = "По имени персонажа"
L["By character level"] = "По уровню персонажа"
L["Sorting of equal levels"] = "Сортировка одинаковых уровней"
L["Show character levels"] = "Показывать уровни персонажей"
L["Show played time this level"] = "Показывать время игры на этом уровне"
L["Show class icons"] = "Показывать иконки классов"
L["Show faction icons"] = "Показывать иконки фракций"
L["None"] = "Ничего"
L["Group by factions"] = "Группировать по фракциям"
L["Current realm only"] = "Только текущий реалм"
L["Current character on top"] = "Текущий персонаж сверху"
L["Current character highlighted"] = "Текущий персонаж выделен"
L["Time in hours (not days)"] = "Время в часах (не днях)"
L["Always show minutes also"] = "Всегда показывать и минуты"
L["Remove character"] = "Удалить персонажа"
L["Broker icon text"] = "Текст иконки Broker"
L["Current character time"] = "Время текущего персонажа"
L["Total time"] = "Общее время"

return end

------------------------------------------------------------------------
-- Korean
------------------------------------------------------------------------

if CURRENT_LOCALE == "koKR" then

L["Played Time"] = "플레이 시간"
L["Right click for settings"] = "우클릭하여 설정"
L["Total"] = "총합"
L["Sorting"] = "정렬"
L["By played time"] = "플레이 시간순"
L["By played time this level"] = "이 레벨 플레이 시간순"
L["By character name"] = "캐릭터 이름순"
L["By character level"] = "캐릭터 레벨순"
L["Sorting of equal levels"] = "동일 레벨 정렬"
L["Show character levels"] = "캐릭터 레벨 표시"
L["Show played time this level"] = "이 레벨 플레이 시간 표시"
L["Show class icons"] = "직업 아이콘 표시"
L["Show faction icons"] = "진영 아이콘 표시"
L["None"] = "없음"
L["Group by factions"] = "진영별 그룹"
L["Current realm only"] = "현재 서버만"
L["Current character on top"] = "현재 캐릭터를 맨 위에"
L["Current character highlighted"] = "현재 캐릭터 강조 표시"
L["Time in hours (not days)"] = "시간 (일 단위 아님)"
L["Always show minutes also"] = "항상 분도 표시"
L["Remove character"] = "캐릭터 삭제"
L["Broker icon text"] = "브로커 아이콘 텍스트"
L["Current character time"] = "현재 캐릭터 시간"
L["Total time"] = "총 시간"

return end

------------------------------------------------------------------------
-- Simplified Chinese
------------------------------------------------------------------------

if CURRENT_LOCALE == "zhCN" then

L["Played Time"] = "游戏时间"
L["Right click for settings"] = "右键点击设置"
L["Total"] = "总游戏时间"
L["Sorting"] = "排序"
L["By played time"] = "按游戏时间"
L["By played time this level"] = "按此等级游戏时间"
L["By character name"] = "按角色名称"
L["By character level"] = "按角色等级"
L["Sorting of equal levels"] = "相同等级排序"
L["Show character levels"] = "角色等级"
L["Show played time this level"] = "显示此等级游戏时间"
L["Show class icons"] = "职业图标"
L["Show faction icons"] = "阵营图标"
L["None"] = "无"
L["Group by factions"] = "按阵营分组"
L["Current realm only"] = "仅限当前服务器"
L["Current character on top"] = "当前角色置顶"
L["Current character highlighted"] = "高亮显示当前角色"
L["Time in hours (not days)"] = "以小时为单位（非天）"
L["Always show minutes also"] = "总是显示分钟"
L["Remove character"] = "移除角色"
L["Broker icon text"] = "Broker 图标文本"
L["Current character time"] = "当前角色时间"
L["Total time"] = "总游戏时间"

return end

------------------------------------------------------------------------
-- Traditional Chinese
------------------------------------------------------------------------

if CURRENT_LOCALE == "zhTW" then

L["Played Time"] = "遊戲時間"
L["Right click for settings"] = "右鍵點擊設定"
L["Total"] = "總遊戲時間"
L["Sorting"] = "排序"
L["By played time"] = "按遊戲時間"
L["By played time this level"] = "按此等級遊戲時間"
L["By character name"] = "按角色名稱"
L["By character level"] = "按角色等級"
L["Sorting of equal levels"] = "相同等級排序"
L["Show character levels"] = "角色等級"
L["Show played time this level"] = "顯示此等級遊戲時間"
L["Show class icons"] = "職業圖示"
L["Show faction icons"] = "陣營圖示"
L["None"] = "無"
L["Group by factions"] = "按陣營分組"
L["Current realm only"] = "僅限目前伺服器"
L["Current character on top"] = "目前角色置頂"
L["Current character highlighted"] = "高亮顯示目前角色"
L["Time in hours (not days)"] = "以小時為單位（非天）"
L["Always show minutes also"] = "總是顯示分鐘"
L["Remove character"] = "移除角色"
L["Broker icon text"] = "Broker 圖示文字"
L["Current character time"] = "目前角色時間"
L["Total time"] = "總遊戲時間"

return end
