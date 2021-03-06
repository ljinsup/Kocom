library(shiny)
library(plyr)
library(rjson)
library(rJava)
library(forecast)
library(googleVis)
library(timeSeries)
library(dygraphs)
library(CEMS)


shinyServer(function(input, output, session) {
  
  dblist <<- as.character(as.list(unlist(publicdatafunc())))
  
  output$text <- renderText({
    invalidateLater(1000, session = NULL)
    toJSON(service)
  })
  
  output$servicetypeselectUI <- renderUI(fixedPage({
    selectInput("type", h4("서비스타입"),
                c("21 현장복합감지",
                  "22 유리창깨짐감지",
                  "23 복합화재감지",
                  "24 복합가스감지",
                  "25 환경감지",
                  "26 비명에의한너스콜",
                  "27 비상자동콜",
                  "28 현관상태감지",
                  "29 창문상태감지",
                  "2a 층간소음감지",
                  "2b 독거인상태감지"
                ), selectize = F)
  }))

  output$CreateUI <- renderUI({fixedPage({
    ######################################
    #        서비스 생성 페이지          #
    ######################################
    
    basicPage(
      sidebarPanel(textOutput("text"), HTML("<br>"), actionButton("init", label = "초기화"), width=12),  
      
      tabsetPanel(id="tab", type="pills",
                  tabPanel("기본 설정",
                           fixedPage(
                             h3("THRESHOLD 설정"),
                             column(2, offset=1,
                                    selectInput("eplsensor", label = NULL, 
                                                choices = servicesensors() )
                             ),
                             column(2, 
                                    selectInput("eploperator", label = NULL, 
                                                choices = c("", ">", ">=", "==", "<=", "<"))
                             ),
                             column(2, 
                                    textInput("eplvalue", label=NULL)
                             ),
                             actionButton("epladd", label = "추가"),
                             actionButton("eplremove", label = "제거"),
                             textInput("serviceid", "서비스 번호:", unlist(strsplit(input$type, split = " "))[1]),
                             textInput("description", "설명:", unlist(strsplit(input$type, split = " "))[2]),
                             
                             textInput("userid", "User_ID:", "USER_01"),
                             textInput("tgid", "TG_ID:", "TG_01"),
                             
                             actionButton("save", label = "저장")                                                           
                           )
                  ),
                  tabPanel("추가설정: 공공데이터 선택",
                           ############### DB UI ###############
                           if(length(dblist)==0){    
                             h1("공공데이터를 넣어주세요")
                             
                           }
                           else{
                             fixedPage(
                               try({
                                 dygraphOutput("dbplot")
                                 #plotOutput("dbplot")
                               }),
                               actionButton("dbadd", label = "추가"),
                               actionButton("dbremove", label = "제거"),
                               actionButton("dbrefresh", label = "새로고침"),
                               
                               selectInput("dbselect", label = h3("공공데이터"),
                                           choices = dbnamelist()
                               ),
                               
                               uiOutput("dbui")
                               
                             )}
                  ),
                  
                  tabPanel("추가설정: 분석 방법 선택",
                           ############### Analysis UI ###############
                           if(length(dblist)==0){
                             h1("공공데이터를 넣어주세요")
                           }
                           else{
                             fixedPage(
                               actionButton("refresh1", label = "새로 고침"),
                               
                               uiOutput("publicselectui"),
                               
                               uiOutput("sensorselectui"),
                               
                               selectInput("analysismethod", label = h4("분석 방법 선택"), 
                                           choices = c("", "예측분석", "비율분석", "비교분석")),
                               
                               actionButton("methodadd", label = "추가"),
                               actionButton("methodremove", label = "제거"),
                               
                               uiOutput("methodui")
                             )}
                  )
                  ,
                  tabPanel("추가설정: 결과 수행 선택",
                           ############### Result UI ###############
                           if(length(dblist)==0){    
                             h1("공공데이터를 넣어주세요")
                           }
                           else{
                             fixedPage(
                               actionButton("refresh2", label = "새로 고침"),
                               
                               uiOutput("resultui"),
                               
                               uiOutput("rangeui"),
                               
                               selectInput("resulttype", label = h3("처리 방법"), 
                                           choices = c("", "추가분석", "Actuator제어")),
                               
                               uiOutput("resulttypeui"),
                               
                               actionButton("resultadd", label = "추가"),
                               actionButton("resultremove", label = "제거")               
                             )}
                  )
                  
                  
      )
    )
    
  })
  })
  
  
  ##############################   DBPLOT   ##############################
  output$dbplot <- renderDygraph({
    
    set <- get(input$dbselect)
    temp <- set[order(set[input$sort]),]
    
  dygraph(timeSeries(temp[[input$attr]], temp[[input$sort]])) %>% 
    dyRangeSelector()
  })    
#     p <- plot(x=temp[[input$sort]],
#               y=temp[[input$attr]],
#               type="l",
#               xlab=input$sort,
#               ylab=input$attr
#     )
#   }, width = 800, height=350)
  
  ##############################   DBSAVE   ##############################
  observeEvent(input$dbadd, function() {
    data <- DB()
    if(!is.null(data$attr)){
      db_info[[length(db_info) +1]] <<- data
      .GlobalEnv$service[["db_info"]] <- .GlobalEnv$db_info
    }
  })
  
  observeEvent(input$dbremove, function() {
    if(length(analysis_info) == 0){
      if(length(db_info) != 0) {
        db_info[[length(db_info)]] <<- NULL
        .GlobalEnv$service[["db_info"]] <- .GlobalEnv$db_info
      }
    }
  })
  ##############################  DB Refresh  ##############################
  dbnamelist <- reactive({
    input$dbrefresh
#    dblist <<- rmongodb::mongo.get.database.collections(mongo_public, attr(mongo_public, "db"))
    
    if(length(dblist)!=0)
      for(i in 1:length(dblist)){
        
        assign(
          dblist[i],
          CEMS::cems.restoreDataType(CEMS::getAllData(mongo_public, dblist[i])),
          envir=.GlobalEnv
        )
        
      }
    return(dblist)
  })
  
  #                                  DB                                  #
  ##############################     UI     ##############################
  output$dbui <- renderUI({
    if (is.null(input$dbselect))
      return()
    
    #     set <- unlist(strsplit(input$dbselect, split=".", fixed=TRUE))[2]
    set <- get(input$dbselect)
    switch(input$dbselect,
           fluidRow(
             column(3,
                    radioButtons("sort", label = h4("기준(가로축)"),
                                 choices = names(set), selected = names(set)[1])
             ),
             column(5,
                    radioButtons("attr", label = h4("값(세로축)"),
                                 choices = names(set), selected = names(set)[2])
             ),
             column(3,
                    checkboxGroupInput("check", label = h4("데이터선택"),
                                       choices = names(set), selected = NULL)
             )
           )
    )
  })
  
  ##############################    FUNC    ##############################
  DB <- reactive({    
    if(!is.null(input$dbselect) && !is.null(input$sort) && !is.null(input$check)){
      res <- list(db=attr(mongo_public, "db"),
                  collection=input$dbselect,
                  sort=input$sort,
                  attr=input$check)
      return(res)
    }
    else return(NULL)
  })
  
  #########################################################################
  
  ###############################  METHODUI  ##############################
  output$methodui <- renderUI({
    input$refresh1
    if( length(.GlobalEnv$db_info)==0 ){
      return()
    }
    
    recentinput <- fromJSON(strtoJSON(input$analysispublic, publicdata()))
    recentpublic <- get(recentinput$collection)
    recentpublic <- recentpublic[order(recentpublic[recentinput$sort]),]
    
    switch(input$analysismethod,
           "예측분석" = 
             fixedPage(
               sliderInput("predrange", "데이터 개수",
                         min = length(forecast(auto.arima(recentpublic[recentinput$attr]))$mean),
                           max = nrow(recentpublic[recentinput$attr])
                           +length(forecast(auto.arima(recentpublic[recentinput$attr]))$mean),
                           value=nrow(recentpublic[recentinput$attr])
                           +length(forecast(auto.arima(recentpublic[recentinput$attr]))$mean),
                           step=1
               ),
               renderPlot({
                 plot(forecast(auto.arima(recentpublic[recentinput$attr])), main="",
                      xlim=c( nrow(recentpublic[recentinput$attr])+length(forecast(auto.arima(recentpublic[recentinput$attr]))$mean)-input$predrange,
                              nrow(recentpublic[recentinput$attr])+length(forecast(auto.arima(recentpublic[recentinput$attr]))$mean) )
                 ) 
               }, width=800)
             ),
           "비교분석" =
             fluidRow(
               sliderInput("comprange", "구간 선택",
                           min = 1,
                           max = nrow(recentpublic[recentinput$attr]),
                           value=c(1, nrow(recentpublic[recentinput$attr])),
                           step=1
               ),
               renderPlot({
                 plot(x=recentpublic[seq(unlist(input$comprange)[1], unlist(input$comprange)[2], by=1), recentinput$sort],
                      y=recentpublic[seq(unlist(input$comprange)[1], unlist(input$comprange)[2], by=1), recentinput$attr],
                      type='l',
                      main="",
                      
                      xlab=recentinput$sort,
                      ylab=recentinput$attr
                      
                 )
                 abline(h=mean(unlist(recentpublic[recentinput$attr])), col="blue")
                 abline(h=max(recentpublic[recentinput$attr]), col="red")
                 abline(h=min(recentpublic[recentinput$attr]), col="red")
               }, width=800)
             ),
           "비율분석" =
             fixedPage(
               column(7, offset=1,
                      renderPlot({
                        pie(count(recentpublic[recentinput$attr])$freq, 
                            labels=paste(count(recentpublic[recentinput$attr])[,recentinput$attr], "(", 
                                         round(count(recentpublic[recentinput$attr])$freq/sum(count(recentpublic[recentinput$attr])$freq)*100, 3), "%)" ,
                                         sep=" ") )
                        
                      }, height=650, width=650)
               ),
               column(2, offset=2,
                      renderTable({
                        count(recentpublic[recentinput$attr])
                      })
               )
             )
    )
  })
  
  ############################## METHODSAVE ##############################
  observeEvent(input$methodadd, function() {
    list <- ANALYSIS()
    list$no <- length(analysis_info)+1
    analysis_info[[length(analysis_info) +1]] <<- list
    .GlobalEnv$service[["analysis"]] <- .GlobalEnv$analysis_info
  })
  
  observeEvent(input$methodremove, function() {
    if(length(resultmnmt) == 0) {
      if(length(analysis_info) != 0) {
        analysis_info[[length(analysis_info)]] <<- NULL
        .GlobalEnv$service[["analysis"]] <- .GlobalEnv$analysis_info
      }
    }
  })
  
  #                                ANALYSIS                               #
  ###############################   DATAUI   ##############################
  output$sensorselectui <- renderUI({
    
    fluidRow({
      radioButtons("analysissensor", label=h3("분석할 센서 선택"),
                   choices = servicesensors() )
    })
  })
  
  servicesensors <- reactive({
    input$type
    list <- list()
    if(is.null(input$type))
      return(list)
    
    type <- unlist(strsplit(input$type, split = " "))[1]
    for(i in 1:nrow(servicetable)){
      if(servicetable[i,type]){
        list <- append(list, as.character(servicetable[i,"SENSOR"]))
      }
    }
    return(unlist(list))
  })
  
  output$publicselectui <- reactiveUI(function() {
    
    if(length(publicdata()) == 0){
      fluidRow({
        h4("공공데이터를 선택하고 새로 고침을 눌러 주세요.")
        
      })
    }else{
      fluidRow({  
        radioButtons("analysispublic", label=h3("공공데이터 선택"),
                     choices = JSONtostr(publicdata(), "collection", "attr" ))
      })
    }
  })
  
  
  
  
  ##############################    FUNC    ##############################
  publicdata <- reactive({
    input$refresh1
    
    if(length(.GlobalEnv$db_info) > 0){
      list <- .GlobalEnv$db_info
      df <- data.frame()
      for(data in list){
        df <- rbind(df, as.data.frame(data))
      }
      list <- list()
      for(i in 1:nrow(df)){
        list[[length(list)+1]] <- toJSON(df[i,])
      }
      return(unlist(list))
    }
  })
  
  ANALYSIS <- reactive({
    list <- list()
    list$sensor <- list(unlist(strsplit(input$analysissensor, split="-"))[1])
    list$public <- list(fromJSON(strtoJSON(input$analysispublic, publicdata()))$attr)
    
    if(input$analysismethod == "비교분석")
      list$method <- "Comparing"
    if(input$analysismethod == "예측분석")
      list$method <- "Predicting"
    if(input$analysismethod == "비율분석")
      list$method <- "Counting"
    
    
    return(list)
  })
  
  #########################################################################
  
  
  #                                 RESULT                                #
  ###############################  RESULTUI  ##############################
  output$resultui <- renderUI(function() {
    if( length( analysisdata() != 0 ) ){
      fluidRow({
        radioButtons("analysislist", label = h3("처리 방법 선택"),
                     choices = JSONtostr(analysisdata(), "no", "sensor", "public", "method"),
                     selected = JSONtostr(analysisdata(), "no", "sensor", "public", "method")[1])
      })
    }
    else{
      fluidRow()
    }
  })
  
  output$rangeui <- reactiveUI(function() {
    if( length( analysisdata() != 0 ) ){
      switch(fromJSON(strtoJSON(input$analysislist, analysisdata()))$method,
             "Predicting" = 
               fluidRow(
                 h4("센서값에 따른 예측 구간"), 
                 img(src = "case.PNG", width = 580, height = 207),
                 selectInput("area", 'Options', c(1, 2, 3, 4, 5, 6), multiple=TRUE, selectize=FALSE)
               ),
             "Comparing" =
               fluidRow(
                 sliderInput("range", "결과 범위",
                             min = -100,
                             max = 100,
                             value=c(-100, 100),
                             step=1
                 )
               ),
             "Counting" =
               fluidRow(
                 sliderInput("range", "결과 범위",
                             min = 0,
                             max = 100,
                             value=c(0, 100),
                             step=1
                 )
               )
      )
    }
    else{
      fluidRow()
    }
  })
  
  output$resulttypeui <- renderUI({
    if (is.null(input$resulttype))
      return()
    
    switch(input$resulttype,
           "추가분석" = fixedPage(
             if(length(analysisdata()) != 0){
               radioButtons("resume", label = h4("분석 방법"),
                            choices = JSONtostr(analysisdata(), "no", "sensor", "public", "method"),
                            selected = NULL)
             }
           ),
           "Actuator제어" = fixedPage(
             selectInput("actuator", label = h4("Actuator종류"), 
                         choices = c("",
                                     "Act01-환기장치",
                                     "Act02-가스차단기", 
                                     "Act03-커튼제어기",
                                     "Act04-실내온도변환기"
                                     
                         )),
             radioButtons("action", label = h4("동작"),
                          choices = c("on", "off"), selected = NULL)
           )
    )
  })
  
  ############################## RESULTSAVE ##############################
  observeEvent(input$resultadd, function() {
    list <- RESULT()
    resultmnmt[[length(resultmnmt) +1]] <<- list
    .GlobalEnv$service[["resultmnmt"]] <- .GlobalEnv$resultmnmt
  })
  
  observeEvent(input$resultremove, function() {
    if(length(epl) == 0){
      if(length(resultmnmt) != 0) {
        resultmnmt[[length(resultmnmt)]] <<- NULL
        .GlobalEnv$service[["resultmnmt"]] <- .GlobalEnv$resultmnmt
      }
    }
  })
  
  ##############################    FUNC    ##############################
  analysisdata <- reactive({
    input$refresh2
    list <- list()
    if(length(.GlobalEnv$analysis_info) > 0){
      for(data in .GlobalEnv$analysis_info){
        list[length(list)+1] <- toJSON(data)
      }
    return(unlist(list))
    }
    else(return(list))
  })
  
  RESULT <- reactive({
    list <- list()
    
    str <- unlist(strsplit(input$analysislist, split="-"))
    
    list$relation <- str[1]
    
    if(str[1] == "Predicting"){
      list$result <- input$area
    }
    else{ 
      list$rate <- input$range
    }
    
    if(input$resulttype == "추가분석"){
      list$type <- "next"
      list$result <- input$area
    }
    else if(input$resulttype == "Actuator제어"){
      list$type <- "act"
      list$actuator_id <- unlist(strsplit(input$actuator, split="-"))[1]
      list$action <- input$action
    }
    else {return}
    
    return(list)
  })
  
  
  #########################################################################
  
  #########################################################################
  observeEvent(input$epladd, function() {  
    messaging <- Progress$new()
    if(inputFix(input$eplvalue, "^[0-9]+$") && input$eplsensor != "" && input$eploperator != "") {
      sensorlist[[length(sensorlist) +1]] <<- input$eplsensor#unlist(strsplit(input$eplsensor, split = "-"))[1]
      sensorlist <<- unique((sensorlist))
      epl[[length(epl) +1]] <<- paste(input$eplsensor, input$eploperator, input$eplvalue, sep=" ")
      
      if(length(sensorlist) == length(epl)){
        .GlobalEnv$service[["sensorlist"]] <- unique(.GlobalEnv$sensorlist)
        .GlobalEnv$service[["epl"]] <- .GlobalEnv$epl
      }
      else{
        
        epl[[length(epl)]] <<- NULL
        .GlobalEnv$service[["sensorlist"]] <- unique(.GlobalEnv$sensorlist)
        .GlobalEnv$service[["epl"]] <- .GlobalEnv$epl
        
      }
    }  
    else {
      messaging$set(message = "잘못된 입력값이 있습니다. (EPL)")
      Sys.sleep(2.0)
      messaging$close()
    }
  })
  #########################################################################
  observeEvent(input$eplremove, function() {
    if(length(epl) != 0) {
      epl[[length(epl)]] <<- NULL
      sensorlist[[length(sensorlist)]] <<- NULL
      .GlobalEnv$service[["epl"]] <- .GlobalEnv$epl
      .GlobalEnv$service[["sensorlist"]] <- .GlobalEnv$sensorlist
    }
  })
  #########################################################################
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  ########################################################################  
  #                           Publicdata List                            #
  ########################################################################
output$PublicUI <- renderUI({
    fixedPage(
      textInput("publicaddr", label = h4("공공데이터 API주소:"), value = "openapi.airkorea.or.kr/openapi/services/rest/ArpltnInforInqireSvc/getMsrstnAcctoRltmMesureDnsty?numOfRows=1&pageNo=1&stationName=%EC%86%A1%ED%8C%8C%EA%B5%AC&dataTerm=DAILY&", width = '100%'),
      textInput("publicapi", label = h4("공공데이터 API키:"), value = "g2PYYeRkm4XwNs5SkT%2BEm6ZWuLXQCBNLJ4jdEH43rTuU0WjKjo%2B2IBtyAr1EJmS2QqsImnnT3RCr5RNBZ0d25A%3D%3D", width = '100%'),
      textInput("publicname", label = h4("공공데이터 이름:"), value = "대기정보데이터"),
      textInput("publicperiod", label = h4("데이터 업데이트 주기(단위: 시간):"), value = "1"),
      actionButton("publicsend", label = "등록")
    )
  })
  
  output$PublicListUI <- renderUI({
    if(is.null(publictabledata())) {
      fixedPage(h1("공공데이터를 넣어주세요."),
                actionButton("refreshpubliclist", "새로 고침")
      )
    }
    else {
      fixedPage(
        checkboxGroupInput("publiclist", label = h4("공공데이터 목록"),
                           choices = publictabledata(), selected = NULL),
        actionButton("publicremove", label = "제거")
      )}
  })
  
  ########################################################################
  publictabledata <- reactive({
    input$refreshpubliclist
    input$publicsend
    input$save
    input$publicremove
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
      return(as.list(paste(res.frame[,1], res.frame[,6], res.frame[,4], res.frame[,2], sep = " ")))
  })
  ########################################################################
  observeEvent(input$publicremove, function() {
    
    .jinit("www/MQTTPublisher.jar")
    mqtt <- .jnew("mqtt/MqttSend")
    
    key <- getAllData(mongo_db, "key")
    key <- as.character(key[1,1])
    topic <- paste(key, "remove", sep = "/")
    
    for(data in input$publiclist){
      list <- list()
      list$id <- unlist(strsplit(data, split = " "))[1]
      
      msg <- toJSON(list)
      mqtt$SEND("127.0.0.1", "1883", topic, msg)
    }
  })
  
  ######################################################################################################
  observeEvent(input$publicsend, function() {
    if(!is.null(input$publicaddr)
       || !is.null(input$publickey)
       || !is.null(input$publicname)
       || inputFix(input$publicperiod, "^[1-9]+$")){
      
      list <- list()
      
      key <- getAllData(mongo_db, "key")
      key <- as.character(key[1,1])
      
      topic <- paste(key, "import", sep = "/")
      
      .jinit("www/MQTTPublisher.jar")
      mqtt <- .jnew("mqtt/MqttSend")
      
      list$url <- input$publicaddr
      list$apikey <- input$publicapi
      list$collection <- input$publicname
      list$period <- input$publicperiod
      
      msg <- toJSON(list)
      #      print(list)  
      rm(list)
      mqtt$SEND("127.0.0.1", "1883", topic, msg) 
      print(topic)
    }
    else {
      messaging <- Progress$new()
      messaging$set(message = "입력값을 확인해주세요.")
      Sys.sleep(2.0)
      messaging$close()
    }
  })
  
  
  
  
  
  
  #########################################################################
  
  
  
  ########################################################################  ########################################################################
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  #                             SERVICE LIST                             #
  ##############################     UI     ##############################
  output$ServiceListUI <- renderUI({
    if(is.null(tabledata())) {
      fixedPage(h1("생성된 서비스가 없습니다."),
                actionButton("refreshpubliclist", "새로 고침")
      )
    }
    else {
      fixedPage(
        checkboxGroupInput("servicelist", label = h4("서비스 목록"),
                           choices = tabledata(), selected = NULL),
        actionButton("serviceremove", label = "제거")
      )}
  })
  
  ##############################    FUNC    ##############################
  tabledata <- reactive({
    input$refreshlist
    input$serviceremove
    res.frame <- data.frame() 
    
    cursor <- mongo.find(mongo=mongo_db,
                         ns=paste(attr(mongo_db, "db"), "service", sep="."),
                         query=mongo.bson.empty(),
                         fields=mongo.bson.from.JSON('{"_id":0, "service_id":1, "description":1}'))
    while(mongo.cursor.next(cursor)){
      res <- mongo.cursor.value(cursor)
      res <- mongo.bson.to.list(res)
      res <- as.data.frame(res)
      res.frame <- rbind(res.frame, res)
    }
    if(nrow(res.frame) == 0)
      return(NULL)
    else
      return(as.list(paste(res.frame[,1], res.frame[,2], sep = " ")))
  })
  
  ########################################################################
  observeEvent(input$serviceremove, function() {
    for(data in input$servicelist){
      bson <- mongo.bson.buffer.create()
      mongo.bson.buffer.append(bson, "service_id", unlist(strsplit(data, split = " "))[1])
      bson <- mongo.bson.from.buffer(bson)
      
      mongo.remove(mongo_db, paste(attr(mongo_db, "db"), "service", sep = "."), bson)
      
    }
  })
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  observeEvent(input$save, function() {
    progress <- Progress$new()
    progress$set(message = "서비스 저장중.")
    
    if((inputFix(input$serviceid, "^[a-z|A-Z|0-9]+$")
            && inputFix(input$description, "^[ㄱ-ㅎ|가-힣|a-z|A-Z|0-9| |*]+$")
            && is.null(.GlobalEnv$service$epl))
         ||
       (inputFix(input$serviceid, "^[a-z|A-Z|0-9]+$")
            && inputFix(input$description, "^[ㄱ-ㅎ|가-힣|a-z|A-Z|0-9| |*]+$")
            && !is.null(.GlobalEnv$service$db_info)
            && !is.null(.GlobalEnv$service$analysis)
            && !is.null(.GlobalEnv$service$resultmnmt))  ){
        progress$set(message = "입력할 데이터가 남았습니다.")
        Sys.sleep(2.0)
        progress$close()
        return()
      }
      
        query <- mongo.bson.buffer.create()
        mongo.bson.buffer.append(query, "service_id", input$serviceid)
        query <- mongo.bson.from.buffer(query)
        
        if( mongo.count(mongo_db, paste(attr(mongo_db, "db"), "service", sep="."), query ) > 0 ){
          progress$set(message = "서비스ID가 중복되었습니다.")
          Sys.sleep(2.0)
          progress$close()
          return()
        }
        
        
        .GlobalEnv$service[["service_id"]] <- input$serviceid
        list <- list()
      sensor <- list()
        actuator <- list()
        desc <- list()
        
        for(data in .GlobalEnv$service[["analysis"]]){
          sensor <- append(data$sensor, sensor)
          sensor <- unique(unlist(sensor))
        }
        
        for(data in .GlobalEnv$service[["resultmnmt"]]){
          if(!is.null(data$actuator_id)){
            actuator <- append(data$actuator_id, actuator)
            actuator <- unique(unlist(actuator))
          }
        }
        list$sensor <- sensor
        list$actuator <- actuator
    
        .GlobalEnv$service[["servicetype"]] <- unlist(strsplit(input$type, split = " "))[1]
        .GlobalEnv$service[["requirement"]] <- list
        .GlobalEnv$service[["description"]] <- input$description
        
        
        progress$set(message = toJSON(service))
        
        q <- mongo.bson.buffer.create()
        mongo.bson.buffer.append(q, "userid", "USER_01")
        mongo.bson.buffer.append(q, "tgid", "TG_01")
        q <- mongo.bson.from.buffer(q)
        cursor <- mongo.find(mongo = mongo_tg, ns = paste(attr(mongo_tg, "db"), "TG_01", sep="."), query = q)
        while(mongo.cursor.next(cursor)){
          criteria <- mongo.cursor.value(cursor)
          criteria <- mongo.bson.to.list(criteria)
        }
        
        objNew <- criteria
        list <- criteria$service
        list <- append(list, .GlobalEnv$service)
        objNew$service <- list
        
            if(mongo.insert(mongo_db,
                            paste(attr(mongo_db, "db"), "service", sep="."),
                            mongo.bson.from.JSON(toJSON(.GlobalEnv$service))) &&
               mongo.update(mongo_tg,
                            paste(attr(mongo_tg, "db"), "TG_01", sep="."),
                            q,
                            mongo.bson.from.list(objNew))
               ){
              progress$set(message = "저장 되었습니다.")
              service <<- list()
              service_id <<- list()
              db_info <<- list()
              analysis_info <<- list()
              resultmnmt <<- list()
              requirement <<- list()
              epl <<- list()
              sensorlist <<- list()  
              Sys.sleep(2.0)
              progress$close()
              }
        
  })
  
  observeEvent(c(input$init, session$request), function() {
    
    messaging <- Progress$new()
    messaging$set(message = "초기화 되었습니다.")
    service <<- list()
    service_id <<- list()
    db_info <<- list()
    analysis_info <<- list()
    resultmnmt <<- list()
    requirement <<- list()
    epl <<- list()
    Sys.sleep(2.0)
    messaging$close()
  })
  
  ########################################################################
  output$RealtimeSensorUI <- renderUI({
    fixedPage(
      selectInput("sensortype", h4("센서 종류"),
                  c("21 현장복합감지",
                    "22 유리창깨짐감지",
                    "23 복합화재감지",
                    "24 복합가스감지",
                    "25 환경감지",
                    "26 비명에의한너스콜",
                    "27 비상자동콜",
                    "28 현관상태감지",
                    "29 창문상태감지",
                    "2a 층간소음감지",
                    "2b 독거인상태감지"
                  ),selected = "21 현장복합감지", selectize = F),
      
      dygraphOutput("realtimesensorplot")
    )
  })
  
  realtimesensordata <- reactive({
    invalidateLater(5000,session)
    input$sensortype
    
    sensordata <- data.frame()
    q <- mongo.bson.buffer.create()
    mongo.bson.buffer.append(q, "dev_type", unlist(strsplit(as.character(input$sensortype), split = " "))[1])
    q <- mongo.bson.from.buffer(q)
    cursor <- mongo.find(mongo=mongo_sensor,
                         ns=paste(attr(mongo_sensor, "db"), "TG_01", sep="."),
                         query=q,
                         sort=mongo.bson.from.JSON('{"time":-1}'),
                         fields=mongo.bson.from.JSON('{"_id":0, "dev_type":0}'),
                         limit = 20)
    
    if(mongo.cursor.next(cursor)){
      res <- mongo.cursor.value(cursor)
      res <- mongo.bson.to.list(res)
      res <- as.data.frame(res)
      sensordata <- rbind.fill(res)
    }
    while(mongo.cursor.next(cursor)){
      res <- mongo.cursor.value(cursor)
      res <- mongo.bson.to.list(res)
      res <- as.data.frame(res)
      sensordata <- rbind.fill(sensordata, res)
    }
    return(sensordata)
  })
  
  output$realtimesensorplot <- renderDygraph({
    invalidateLater(5000,session)
    
    sensordata <- realtimesensordata()
    if(nrow(sensordata) !=0){
    dygraph(timeSeries(sensordata[,],sensordata$time))  %>% 
      dyOptions(connectSeparatedPoints = TRUE) %>% 
      dyLegend(show = "follow")
    }
    
  })
  
  ########################################################################
  output$AnalysisLogUI <- renderUI({
    logdata <- readlogdata()
    
    if(is.null(logdata)){
      fluidPage({
        actionButton("logrefresh", "새로 고침")
        h1("tests")
      })
    }
    else
    {
      fixedPage({
        actionButton("logrefresh", "새로 고침")
        htmlOutput("logdatatable")
      })
    }
  })
  
  output$logdatatable <- renderGvis({
    data <- readlogdata()
    Table <- gvisTable(data)
  })
  
  readlogdata <- reactive({
    input$logrefresh
    
    res.frame <- data.frame() 
    
    cursor <- mongo.find(mongo=mongo_log,
                         ns=paste(attr(mongo_log, "db"), "TG_01", sep="."),
                         query=mongo.bson.empty(),
                         sort=mongo.bson.from.JSON('{"datatime":-1}'),
                         fields=mongo.bson.from.JSON('{"_id":0}'),
                         limit = 100)
    
    if(mongo.cursor.next(cursor)){
      res <- mongo.cursor.value(cursor)
      res <- mongo.bson.to.list(res)
      res$service <- toJSON(res$service)
      res <- res[c(4:1)]
      res <- as.data.frame(res)
      res.frame <- rbind(res)
    }
    while(mongo.cursor.next(cursor)){
      res <- mongo.cursor.value(cursor)
      res <- mongo.bson.to.list(res)
      res$service <- toJSON(res$service)
      res <- res[c(4:1)]
      res <- as.data.frame(res)
      res.frame <- rbind(res.frame, res)
    }
    
    if(nrow(res.frame) == 0)
      return(NULL)
    else
      return(res.frame)
  })
  
})