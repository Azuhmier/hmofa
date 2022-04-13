#!/usr/bin/env python3

init_url = 'https://desuarchive.org/trash/search/text/%22Human%20Males%20On%20Female%20Anthros%20General%22/type/op/'

import requests
session = requests.Session()
r = session.get(init_url)

from bs4 import BeautifulSoup
soup = BeautifulSoup(r.content, 'html.parser')

mydivs  = soup.find_all("div", {"class": "container-fluid"})
mydivs2 = mydivs[0].find_all("div", {"id": "main"})
article = mydivs2[0].find_all("article", {"class":"clearfix thread"})
aside = article[0].find_all("aside", {"class":"posts"})
articles = aside[0].find_all("article")

for article in articles :
    txt = article.find_all("div", {"class":"text"})
    for e in txt[0].findAll('br'):
        e.extract()
    for line in txt[0] :
        print(line.string)
#html body.theme_default.midnight div.container-fluid div#main article.clearfix.thread aside.posts article#46820967.post.doc_id_47765430.post_is_op.has_image div.post_wrapper div.text a
#\34 6820967 > div:nth-child(2) > div:nth-child(5) > a:nth-child(17)
#/html/body/div[2]/div[2]/article[1]/aside/article[1]/div[2]/div[4]/a[2]
