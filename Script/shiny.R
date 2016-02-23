install.packages("shiny", repos="http://cran.nexr.com")
library(shiny)
setwd("Kocom/Kocom/Shiny")
runApp(host="0.0.0.0", port=20000)