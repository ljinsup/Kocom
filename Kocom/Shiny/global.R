
CEMS::checkpkg("forecast", "googleVis")

service <<- list()
service_id <<- list()
servicetype <<- list()
db_info <<- list()
analysis_info <<- list()
resultmnmt <<- list()
requirement <<- list()
epl <<- list()
sensorlist <<- list()
colllist<<- list()


DBHOST <- "localhost"
DBPORT <- 30000

mongo_db <- CEMS::connectMongo(Addr = DBHOST, DB="scconfig", port=DBPORT)
mongo_user <- CEMS::connectMongo(Addr = DBHOST, DB="userdata", port=DBPORT)
mongo_tg <- CEMS::connectMongo(Addr = DBHOST, DB="sensordata", port=DBPORT)
mongo_public <- CEMS::connectMongo(Addr = DBHOST, DB="publicdata", port=DBPORT)
mongo_usgs <- CEMS::connectMongo(Addr = DBHOST, DB="usgsdata", port=DBPORT)

for(coll in colllist){
  if(coll[,2]=="TRUE")
    dblist <- append(dblist, coll[,3])
}


servicetable <- data.frame(c("GA", "GB", "VB", "IR", "AC", "TH", "MA", "DB", "CS", "FL", "SH"))
servicetable <- cbind(servicetable, c(T,T,T,T,T,T,T,T,F,F,F))
servicetable <- cbind(servicetable, c(F,F,F,F,T,F,F,F,F,F,T))
servicetable <- cbind(servicetable, c(T,T,F,F,F,T,F,F,F,T,T))
servicetable <- cbind(servicetable, c(T,T,F,F,F,F,F,F,F,F,F))
servicetable <- cbind(servicetable, c(F,T,F,F,F,T,F,F,T,T,F))
servicetable <- cbind(servicetable, c(F,F,T,F,T,F,F,F,F,F,T))
servicetable <- cbind(servicetable, c(F,F,F,F,T,F,F,T,F,F,F))
servicetable <- cbind(servicetable, c(F,F,F,T,T,F,T,F,F,F,F))
servicetable <- cbind(servicetable, c(F,F,T,T,T,F,F,F,F,F,F))
servicetable <- cbind(servicetable, c(F,F,F,F,F,F,F,T,F,F,T))
servicetable <- cbind(servicetable, c(F,F,T,F,T,F,F,F,T,F,T))
names(servicetable) <- c("SENSOR", 21:29, "2A", "2B")


#dblist <- rmongodb::mongo.get.database.collections(mongo_db, attr(mongo_db, "db"))
tglist <- rmongodb::mongo.get.database.collections(mongo_user, attr(mongo_user, "db"))


if(length(tglist)!=0)
  for(i in 1:length(tglist)){
  if(length(tglist))
    break
  assign(
    unlist(strsplit(tglist[i], split=".", fixed=TRUE))[2],
    mongo.cursor.value(mongo.find(mongo_user, tglist[i])),
    envir=.GlobalEnv
  )
}


JSONtostr <- function(jsonlist, ...){
  list <- list()
  str <- NULL
#    if() {
#      
#    }
#    else {
    for(json in jsonlist){
      str <- NULL
      data <- fromJSON(json)
      
      for(l in list(...)){
        if(!is.null(data[[l]])){
          if(is.null(str)){
            str <- as.character(data[[l]])
          }
          else{
            str <- paste(str, as.character(data[[l]]), sep="-")
          }
        }
      }
      list[length(list)+1] <- str
    }
  return(unlist(list))
#    }
}

strtoJSON <- function(str, jsonlist){
#   if() {
#      
#   }
#   else {
      list <- unlist(strsplit(str, split="-"))
      for(json in jsonlist){
        data <- fromJSON(json)
          if(is.include(list, unlist(data))){
            return(json)
          }
      }
#         }
}

inputFix <- function(input, Regexp){
  if(!is.integer0(grep(x=input, pattern=Regexp)))
    return(TRUE)
  else
    return(FALSE)
}


publicdatafunc <- function(){
  res.frame <- data.frame() 
  
  cursor <- mongo.find(mongo=mongo_db,
                       ns=paste(attr(mongo_db, "db"), "pdList", sep="."),
                       query=mongo.bson.empty(),
                       fields=mongo.bson.from.JSON('{"_id":0}'))
  
  if(mongo.cursor.next(cursor)){
    res <- mongo.cursor.value(cursor)
    res <- mongo.bson.to.list(res)
    res <- as.data.frame(res)
    res.frame <- rbind(res)
  }
  while(mongo.cursor.next(cursor)){
    res <- mongo.cursor.value(cursor)
    res <- mongo.bson.to.list(res)
    res <- as.data.frame(res)
    res.frame <- rbind(res.frame, res)
  }
  if(nrow(res.frame) == 0)
    return(NULL)
  else
    return(unique(as.list(as.character(res.frame[,4]))))
}





