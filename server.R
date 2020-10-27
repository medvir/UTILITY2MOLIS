# Utility2MOLIS

library(shiny)
library(readxl)
library(tidyverse)

shinyServer(function(input, output, session) {
    
    raw_data <- reactive({

        # only run if a pcr_file is uploaded
        req(input$pcr_file)
      
        read_excel(input$pcr_file$datapath) %>%
            select(`File name`, `Creation date/time`, `Negative control ID`, `Sample ID`, `Channel No.`,
                   `Sample overall result (orig.)`, `Target result (orig.)`, `RFI`, `CT (orig.)`, `Channel result (orig.)`)
    })
    
    filename <- reactive({raw_data()$`File name`[1]})
    date <- reactive({raw_data()$`Creation date/time`[1]})
    NC <- reactive({raw_data()$`Negative control ID`[1]})
   
    tidy_data <- reactive({
        raw_data() %>%
            select(-`File name`, -`Creation date/time`, -`Negative control ID`) %>%
            mutate(Ct = as.numeric(`CT (orig.)`)) %>%
            mutate(Target = case_when(
                `Channel No.` == 2 ~ "E_Gen",
                `Channel No.` == 5 ~ "IC",
                TRUE ~ NA_character_)) %>%
            select(`Sample ID`, Target, Ct) %>%
            pivot_wider(names_from = Target, values_from = Ct) %>%
            mutate(Result = case_when(
                E_Gen < 45 ~ "Positiv",
                IC >= 30 & IC <= 40 & is.na(E_Gen) ~ "Negativ",
                TRUE ~ "Invalid")) %>%
            mutate(VL = signif(10^((E_Gen - 47.251)/-3.272),2)) %>%  #-3.272	47.251
            arrange(Result, `Sample ID`) %>%
            select(`Sample ID`, IC, E_Gen, VL, Result)
    })
  
    ### table
    output$results <- renderTable({
        tidy_data() 
    })

    
   
    ### Download
    output$pdf_export <- downloadHandler(
        
        filename = function() {
            # take the same base name of the export as the report file name
            base_name <- sub("\\.xls.*$", "", input$pcr_file$name) 
            paste0(base_name, ".pdf")
        },
        
        content = function(file) {
            tempReport <- file.path(tempdir(), "report.Rmd")
            file.copy("report.Rmd", tempReport, overwrite = TRUE)
            
            params <- list(filename = filename(),
                           date = date(),
                           tidy_data = tidy_data(),
                           git_tag = system("git describe --abbrev=0 --tags", intern=TRUE),
                           git_id_short = system("git rev-parse --short HEAD", intern=TRUE))
            
            rmarkdown::render(tempReport, output_file = file,
                              params = params,
                              envir = new.env(parent = globalenv()))
        })
})
