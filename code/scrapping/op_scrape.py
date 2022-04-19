#!/usr/bin/env python3
import requests
from bs4 import BeautifulSoup
import time
import re
import pprint
pp = pprint.PrettyPrinter(indent=4)
re_author =  re.compile("^\s*[Bb]y\s\s*(.*)")
re_title  =  re.compile("^>\s*([^()]*)")
re_url    =  re.compile("(^http[^ ]*)")
re_end    =  re.compile("^\[")
url_head = 'https://desuarchive.org/trash/search/text/%22Human%20Males%20On%20Female%20Anthros%20General%22/type/op/page/'
session = requests.Session()
db = []
for num in range(1) :
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
        for line in div.get_text(separator="\n").splitlines() :
            author = re_author.match(line)
            title  = re_title.match(line)
            url    = re_url.match(line)
            if flag :
                if author :
                    hsh["authors"].append({ "author" : author.group(1) })
                    hsh["authors"][-1]["titles"] = []
                elif title :
                    hsh["authors"][-1]["titles"].append({ "title" : title.group(1) })
                    hsh["authors"][-1]["titles"][-1]["urls"] = []
                elif url :
                    hsh["authors"][-1]["titles"][-1]["urls"].append({ "url" : url.group(1) })
                elif re_end.match(line) :
                    break
            if title :
                flag = 1
        db.append(hsh)
    time.sleep(2.4)
#pp.pprint(db)

authors = {}
urls = {}
titles = {}
for OP in db[::-1] :
    idx = 0
    for author in OP["authors"] :
        idx += 1

        if not author["author"] in authors :
            authors[author["author"]] = {}

        if not "prev_idx" in authors[author["author"]] :
            authors[author["author"]]["prev_idx"] = 0
            print("updated on " + OP["date"] + " " + str(author))
        else :
            authors[author["author"]]["prev_idx"] = authors[author["author"]]["idx"]

        authors[author["author"]]["idx"] = idx

        if authors[author["author"]]["idx"] < authors[author["author"]]["prev_idx"] :
            print("updated on " + OP["date"] + " " + str(author))

#author index change
#title index change
#title attribute change
#url index change
#url attribute change
#make excpeption for anonymous
#account for the first authors of the first OP, do not count them as updated
