extends RefCounted

func normalize(text: String) -> String:
	text=text.to_lower().replace("œ","oe")
	for group in [["àâä","a"],["éèêë","e"],["îï","i"],["ôö","o"],["ùûü","u"],["ç","c"]]:
		for character in group[0]: text=text.replace(character,group[1])
	var pattern := RegEx.new()
	pattern.compile("[^a-z0-9]+")
	return pattern.sub(text," ",true).strip_edges()

func matches(text: String, phrase: String) -> bool:
	return (" "+normalize(phrase)+" ") in (" "+text+" ")

func find_topic(id: String, sheet: Dictionary) -> Dictionary:
	for row in sheet.chat_topics:
		if row.id==id: return row
	return sheet.chat_topics[-1]

func restore_memory(saved: Dictionary, sheet: Dictionary) -> Dictionary:
	var result := {}
	for key in ["name","last_reply","topic"]:
		if saved.get(key) is String: result[key]=saved[key].left(24 if key=="name" else int(sheet.local_chat[0].response_limit))
	if result.get("topic","")!=find_topic(result.get("topic",""),sheet).id: result["topic"]=""
	result["turn"]=clampi(int(saved.get("turn",0)),0,1000000)
	result["mood"]=clampi(int(saved.get("mood",0)),-2,2)
	result["counts"]={}
	result["followups"]={}
	if saved.get("counts") is Dictionary:
		for row in sheet.chat_topics:
			if saved.counts.get(row.id) is int or saved.counts.get(row.id) is float:
				result.counts[row.id]=clampi(int(saved.counts[row.id]),0,1000000)
	if saved.get("followups") is Dictionary:
		for row in sheet.chat_topics:
			if saved.followups.get(row.id) is int or saved.followups.get(row.id) is float:
				result.followups[row.id]=clampi(int(saved.followups[row.id]),0,1000000)
	return result

func classify(text: String, sheet: Dictionary) -> Dictionary:
	var selected: Dictionary = sheet.chat_topics[-1]
	var best_score := 0.0
	for row in sheet.chat_topics:
		var score := 0.0
		var hits := 0
		for keyword in row.keywords:
			if keyword!="*" and matches(text,keyword):
				score=maxf(score,normalize(keyword).split(" ").size()*2.0)
				hits+=1
		if hits>0: score += hits*0.2+float(row.get("priority",0))
		if score>best_score:
			best_score=score
			selected=row
	return selected

func reply(words: String, context: Dictionary, memory: Dictionary, sheet: Dictionary) -> String:
	var text := normalize(words.left(int(sheet.local_chat[0].message_limit)))
	var turn := int(memory.get("turn",0))
	memory["turn"]=turn+1
	var personality: Dictionary = sheet.chat_personalities[0]
	for row in sheet.chat_personalities:
		if row.id==context.race: personality=row
	var values := context.duplicate()
	values["race"]=personality.race_name
	values["origin"]=personality.origin
	values["preference"]=personality.preference
	values["hobby"]=personality.hobby
	values["flavor"]=personality.flavors[turn%personality.flavors.size()]
	values["player"]=memory.get("name","chef")
	var name_pattern := RegEx.new()
	name_pattern.compile("(?:^| )(?:je m appelle|moi c est|mon nom est|appelle moi) ([a-z0-9]+(?: [a-z0-9]+)?)")
	var name_match := name_pattern.search(text)
	if name_match:
		var name: String = name_match.get_string(1).split(" ")[0].capitalize().left(24)
		memory["name"]=name
		memory["topic"]="greeting"
		var introduction := "Enchanté, %s ! Moi, c’est %s. %s" % [name,context.name,values.flavor]
		memory["last_reply"]=introduction
		return introduction
	var follow_up := false
	for phrase in ["pourquoi","pourquoi ca","comment ca","et ensuite","raconte","raconte moi","oui","ok","d accord","vas y","et alors","continue","continue ton histoire","raconte la suite","la suite","suite","et apres","encore","dis m en plus","developpe","explique"]:
		if text==phrase: follow_up=true
	var topic: Dictionary = sheet.chat_topics[-1]
	if follow_up and not str(memory.get("topic","")).is_empty():
		topic=find_topic(memory.topic,sheet)
	else:
		topic=classify(text,sheet)
	memory["topic"]=topic.id
	var counts: Dictionary = memory.get("counts",{})
	var count := int(counts.get(topic.id,0))
	counts[topic.id]=count+1
	memory["counts"]=counts
	var index := posmod(str(context.race).hash()+count,topic.responses.size())
	var followups: Dictionary = memory.get("followups",{})
	var follow_count := int(followups.get(topic.id,0))
	var template: String = topic.responses[index]
	if follow_up:
		template=topic.followups[follow_count%topic.followups.size()]
		followups[topic.id]=follow_count+1
		memory["followups"]=followups
	if topic.id=="story":
		values["story"]=personality.story[count%personality.story.size()]
	values["customs"]=personality.customs
	values["dream"]=personality.dream
	if topic.id=="remember_name" and not memory.has("name"):
		template="Vous ne m’avez pas encore donné votre nom. Vous pouvez écrire : « Je m’appelle… »"
	var result := template.format(values)
	if follow_up and result==memory.get("last_reply",""):
		result=str(topic.responses[index]).format(values)
	if result==memory.get("last_reply","") and topic.responses.size()>1:
		result=str(topic.responses[(index+1)%topic.responses.size()]).format(values)
	var mood := int(memory.get("mood",0))
	if topic.id=="dismiss": mood=-2
	elif topic.id=="insult": mood=maxi(-2,mood-1)
	elif topic.id in ["thanks","compliment"]: mood=mini(2,mood+1)
	memory["mood"]=mood
	if mood==-2 and topic.id not in ["dismiss","insult","thanks","compliment"]:
		result="Parlons calmement. "+result
	result=result.left(int(sheet.local_chat[0].response_limit))
	memory["last_reply"]=result
	return result
