from bs4 import BeautifulSoup
myfile = '/home/azuhmier/hmofa/hmofa/.ohm/output/newbin.html'
lh = open(myfile, 'r')

soup = BeautifulSoup(lh,'html.parser')
prettyHTML=soup.prettify()


with open(myfile, "w") as f:
    f.write(prettyHTML)
    f.close()
