library(shiny)

shinyUI(basicPage(
#   uiOutput("CreateUI")
  

  img(src = "logo.png", width = 600, height = 100),
  tabsetPanel(id="tab",
            
              tabPanel("공공데이터 추가",
                       fluidPage(
                         uiOutput("PublicUI")
                       )
              ),
              tabPanel("공공데이터 목록",
                       fixedPage(
                         uiOutput("PublicListUI")
                       )
              ),
              tabPanel("서비스 생성",
                       fixedPage(
                         uiOutput("servicetypeselectUI"),
                         uiOutput("CreateUI")
                       )
              ),
              tabPanel("서비스 목록",
                       fixedPage(
                         uiOutput("ServiceListUI")
                       )
              ),
              tabPanel("센서데이터 확인",
                       fixedPage(
                         uiOutput("RealtimeSensorUI")
                       )
              ),
              tabPanel("데이터 분석 상태 확인",
                       fixedPage(
                         uiOutput("RealtimeAnalyUI")
                       )
              )
  )
  ))