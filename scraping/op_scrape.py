#!/usr/bin/env python3
import requests
from bs4 import BeautifulSoup
import time
import re
import pprint
import numpy as np
import copy

Bad_Threads = [
    "47044936",
]
corrections = {
        "authors" : {
            "kaktus" : [ "kaktus-nsfw" ],
            "namechangedaily" : [ "changed_daily" ],
        },
        "titles" : {
            "Change Your Mind Issue" : ["change your mind"],
            "my waspu" : ["my waspfu"],
        },
        "urls" : {
        },
}

#######################
##------ FETCH ----- ##
#######################

pp = pprint.PrettyPrinter(indent=4)
re_author =  re.compile("^\s*[Bb]y\s\s*(.*)")
re_title  =  re.compile("^>\s*(.+?)\s*([(\[].+[)\]])*$")
re_url    =  re.compile("^(http[^ ]+?)\s*([(\[].+[)\]])*$")
re_end    =  re.compile("^\[")
re_begin  =  re.compile("^\s*-*[sS]tories-*\s*$")

url_head = 'https://desuarchive.org/trash/search/text/%22Human%20Males%20On%20Female%20Anthros%20General%22/type/op/page/'
session = requests.Session()
OP_list  = []
OPs_text = []
#for num in range(1,1) :
for num in [1] :
    url = url_head+str(num)
    r = session.get(url)
    soup = BeautifulSoup(r.content, 'html.parser')
    posts = soup.find_all("article", {"class" : re.compile("post doc_id_")})
    for post in posts :
        hsh = {}
        hsh["thread_num"] = post["id"]
        date = re.compile("4chan Time: (.*)")
        hsh["date"] = date.match(post.find("span", {"class" : "time_wrap"}).time["title"]).group(1)
        div = post.find("div", {"class" : "text"})
        hsh["authors"] = [];
        pointer = hsh["authors"]
        flag = 0
        OPs_text.append("--------------------------------------------")
        OPs_text.append("---------" + str(hsh["date"]) + "-----------")
        OPs_text.append("--------------------------------------------")
        for line in div.get_text(separator="\n").splitlines() :
            author = re_author.match(line)
            title  = re_title.match(line)
            url    = re_url.match(line)
            begin  = re_begin.match(line)
            if flag :
                if author :
                    hsh["authors"].append({ "author" : author.group(1) })
                    hsh["authors"][-1]["titles"] = []
                    OPs_text.append("    " + line)
                elif title :
                    hsh["authors"][-1]["titles"].append({ "title" : title.group(1) })
                    hsh["authors"][-1]["titles"][-1]["attr"] = title.group(2)
                    hsh["authors"][-1]["titles"][-1]["urls"] = []
                    OPs_text.append("        " + line)
                elif url :
                    hsh["authors"][-1]["titles"][-1]["urls"].append({ "url" : url.group(1) })
                    hsh["authors"][-1]["titles"][-1]["urls"][-1]["attr"] = url.group(2)
                    OPs_text.append("            " + line)
                elif re_end.match(line) :
                    break
            if begin :
                flag = 1
        OP_list.append(hsh)
    time.sleep(2.4)
#pp.pprint(OP_list)

#######################
##------ DIVY ------ ##
#######################
#def divy(lst, itemName, stack, db, cycle, updated, top, skip, OP) :
#
#    ## ITEM LIST
#    itemIdx = 0
#    for item in lst :
#        itemIdx += 1
#        key = item[itemName]
#
#        if itemName == 'author' :
#            updated = 0
#            top     = item
#
#        # CONVERT itemName TO LOWERCASE
#        if itemName in ['author', 'title'] :
#            key = key.lower()
#
#        ## NEW db ENTRY
#        if key not in db :
#            db[key] = {}
#            db[key]["cycle"] = -1
#
#        if key not in skip  :
#            if db[key]["cycle"] != cycle :
#
#                ## CREATION
#                if not "idxs" in db[key] :
#                    db[key]["idxs"] = [0]
#                    if not updated :
#                        updated = 1
#                        print("index created on "        \
#                                + OP["date"] + " "       \
#                                + OP["thread_num"] + " " \
#                                + str(item))
#                db[key][ "idxs" ].append(itemIdx)
#
#                ## CREATION
#                if db[key][ "idxs" ][-1] < db[key][ "idxs" ][-2] :
#                    if not updated :
#                        updated = 1
#                        print("index decreased on "         \
#                                + OP["date"] + " "       \
#                                + OP["thread_num"] + " " \
#                                + str(item))
#
#                db[key][ "cycle" ] = cycle
#
#        if "stack" not in stack[-1][itemName + "s"][itemIdx - 1] :
#            stack[-1][itemName + "s"][itemIdx-1]["stack"] = []
#        stack[-1][itemName + "s"][itemIdx - 1]["stack"].append(copy.deepcopy(item))
#
#        ## GO TO CHILDS
#        not_matching = re.compile( itemName + "|attr|stack|cycle|idxs|OP" )
#        childNameAr = [s for s in item.keys() if not not_matching.search(s)]
#        if childNameAr :
#            childName = childNameAr[0]
#            if "db" not in db[key] :
#                db[key]["db"] = {};
#            divy( **{
#                "lst"      : item[ str(childName) ],
#                "itemName" : childName.rstrip(childName[-1]),
#                "stack"    : stack[-1][itemName + "s"][itemIdx-1]["stack"],
#                "db"       : db[key]["db"],
#                "cycle"    : cycle,
#                "updated"  : updated,
#                "top"      : top,
#                "skip"     : '',
#                "OP"       : OP,
#            } )
#
#    ## Wholistically find what was added and what was not
#    #try:
#    #    stack[-2]
#    #except IndexError:
#    #    return 1
#    #current_items = []
#    #for item in stack[-1][ str(itemName)+"s" ] :
#    #    current_items.append(key)
#    #previous_items = []
#    #for item in stack[-2][ str(itemName)+"s" ] :
#    #    previous_items.append(key)
#    #main_list = np.setdiff1d(previous_items,current_items)
#    #main_list2 = np.setdiff1d(current_items,previous_items)
#    #if len(main_list) :
#    #    print("    removed " + str(main_list))
#    #if len(main_list2) :
#    #    print("    added " + str(main_list2))
#
#
#
###############################
###------ GET CHANGES ------ ##
###############################
#stack = []
#cycle = 1
#db = {}
#for OP in OP_list[::-1] :
#
#    itemName = "author"
#    stack.append(OP)
#
#    divy( **{
#        "lst"       : OP[ str(itemName)+"s" ],
#        "itemName"  : itemName,
#        "stack"     : stack,
#        "db"        : db,
#        "cycle"     : cycle,
#        "updated"   : 0,
#        "top"       : '',
#        "skip"      : ["anonymous","anon"],
#        "OP"        : OP
#    } )
#
#    cycle += 1
#
#
#with open("op_list.txt", "w") as f:
#    for item in OPs_text:
#        f.write("%s\n" % item)
#
### CASES
## index changes and creation
## attribute changes
## ignore anonymous indexe changes and creations
## account for the first authors of the first OP
#
### complications
## mistakes
## null updates
## overflow
#
### ALOGARYTHM
