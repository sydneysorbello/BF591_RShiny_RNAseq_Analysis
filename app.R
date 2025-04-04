## Author: Sydney Sorbello
## sorbello@bu.edu
## BU BF591
## Final Project

#if (!require("BiocManager", quietly = TRUE))
#  install.packages("BiocManager")
#BiocManager::install("fgsea")
#BiocManager::install("ComplexHeatmap")
#BiocManager::install("org.Hs.eg.db")

# Lets Install the necessary packages!
library(shiny)
library(bslib)
library(ggplot2)
library(colourpicker)
library(shinythemes)
library(readr)
library(dplyr)
library(tidyr)
library(ggridges)
library(DT)
library(ComplexHeatmap)
library(tidyverse)
library(circlize)
library(fgsea)
library(org.Hs.eg.db)

# we can define a set of variables outside of the app and then call it later on
# these represent the choices of plot axes later on
choices <- c("baseMean", "log2FoldChange", "lfcSE", "stat", "pvalue", "padj")

# Define UI
ui <- fluidPage(
  # add a title panel
  titlePanel("BF591 RShiny RNAseq Analysis"),
  # and a description of the website
  HTML("<p> Welcome to Sydney's Final Project Page! <p>"),
  # here we designate the sidebar layout
  # this is where we take all of the user input
  tabsetPanel(
    # the first tab in the app allows us to view characteristics of the samples metadata
    tabPanel("Samples",
             sidebarLayout(
               sidebarPanel(
                 # this defines a space for the user to upload data
                 fileInput("Tab1Input", "Load descriptive sample data"),
                 hr(),
                 # in the side bar, the user can customize the ridgeline plot
                 tabPanel("Ridgeline Plot",
                          # based on the metadata they have uploaded, they can select variable for the plot
                          selectInput("ridge_var", "Select a Continuous Variable:",
                                      choices = NULL), 
                          selectInput("ridge_group", "Group By (Categorical Variable):",
                                      choices = NULL),
                          sliderInput("bin_width", "Adjust Bin Width:", 
                                      min = 0.5, max = 5, value = 1, step = 0.5),
                          checkboxInput("scale_density", "Scale Densities", value = TRUE))
               ),
               # the main panel features three tabs
               mainPanel(
                 tabsetPanel(
                   # a summary table
                   tabPanel("Summary", tableOutput("metadata")),
                   # a sample table sotring column information
                   tabPanel("Table", DT::dataTableOutput("sampletable")),
                   # and finally a ridgline plot
                   tabPanel("Ridgeline Plot",
                            plotOutput("ridgeline_plot"))
                 )
               ))),
    # the second table displays count information complete with a heatmap, PCA and diagnostic plot
    tabPanel("Counts",
             sidebarLayout(
               sidebarPanel(
                 # The user can upload the normalized counts matrix
                 fileInput("counts", "Load normalized counts data"),
                 # and specify thresholds for the counts summary
                 sliderInput("var_threshold", "Select to include genes with at least X percentile of variance", 0, 100, 50),
                 sliderInput("zero_threshold", "Select to include genes with at least X samples that are non-zero", 0, 10, 5),
                 # the user can alsochoose the plot type for the diagnostic plot variance or zeros
                 radioButtons("plot_type", "Select Diagnostic Plot:",
                              choices = list("Median Count vs Variance" = "variance",
                                             "Median Count vs Number of Zeros" = "zeros"),
                              selected = "variance"),
                 hr(),
                 # finally, they can specify is they would like to view the heatmap log-transformed (recommended)
                 checkboxInput("log_transform", "Log-Transform Counts for Heatmap", value = TRUE)
               ),
               mainPanel(
                 tabsetPanel(
                   # there are 4 tabs in the main panel: counts summary table, diagnostic plot, heatmap, and PCA plot
                   tabPanel("Summary", tableOutput("countssummary")),
                   tabPanel("Diagnostic Plots", plotOutput("scatter_plot")),
                   tabPanel("Heatmap", plotOutput("heatmap_plot")),
                   tabPanel("PCA Plot",
                            h3("Principal Component Analysis (PCA) Projections"),
                            selectInput("pc_x", "Select X-axis PC:", choices = c("PC1", "PC2", "PC3"), selected = "PC1"),
                            selectInput("pc_y", "Select Y-axis PC:", choices = c("PC1", "PC2", "PC3"), selected = "PC2"),
                            plotOutput("pca_plot"))
                 )
               ))),
    # The next main tab explores differential expression
    tabPanel("DE",
             sidebarLayout(
               sidebarPanel(
                 # first we ask them to input a file
                 fileInput("Input", "Load Differential Expression Data"),
                 # and give instruction on how to make a volcano plot
                 HTML("<p> A volcano plot can be produced from Log2FoldChange on the x-axis and p-adj on the y axis <p>"),
                 # we use two sets of radio buttons, one for the x axis and and one for the y axis
                 radioButtons("choices1", "Choose the column for the x-axis", choices),
                 radioButtons("choices2", "Choose the column for the y-axis", choices),
                 # now we let the user make color inputs
                 colourInput("color1", "Base Point Color", "blue"),
                 colourInput("color2", "Highlight Point Color", "orange"),
                 # and add a slider to input the padjusted threshold
                 sliderInput("threshold", "Select the magnitude of the p adjusted coloring", -300, 0, -150)
                 # finally an action button
               ),
               # now we make a main panel with two tabs
               mainPanel(
                 tabsetPanel(
                   # one to display the plot
                   tabPanel("Plot", plotOutput("volcano")),
                   # and the other to display the table
                   tabPanel("Table", tableOutput("table"))
                 )))),
    # the final tab explores gene set enrichment analysis
    tabPanel("GSEA",
             sidebarLayout(
               sidebarPanel(
                 # we ask the user to upload the DEseq results
                 fileInput("deseq_file", "Upload Differential Expression Results (CSV)",
                           accept = c(".csv", ".tsv")),
                 # we also ask that they provide a gene set database with a file sufix of .gmt
                 fileInput("gmt_file", "Upload Gene Set Database (GMT)", 
                           accept = c(".gmt")),
                 hr(),
                 tabsetPanel(
                   # within the side panel, there are more tabs
                   # the first allows for input on the barplot
                   tabPanel("barplot NES",
                            sliderInput("top_pathways", "Number of Top Pathways:",
                                        min = 5, max = 50, value = 10, step = 1)),
                   # the second for input on the results table (with a p-adjusted filter)
                   tabPanel("Results Table",
                            sliderInput("padj_filter", "Filter by Adjusted P-value:",
                                        min = 0, max = 0.1, value = 0.05, step = 0.01),
                            # here they can specifiy the desired direction
                            radioButtons("nes_direction", "NES Direction:",
                                         choices = list("All" = "all",
                                                        "Positive NES" = "pos",
                                                        "Negative NES" = "neg"),
                                         selected = "all"),
                            # finally they can download the results of the significant pathways
                            downloadButton("download_results", "Download Results")),
                   tabPanel("Scatter Plot",
                            sliderInput("padj_filtered_scatter", "Filter by Adjusted P-value:",
                                        min = 0, max = 0.1, value = 0.05, step = 0.01))
                 )
               ),
               # the main panel displays 3 tabs: one for the barplot of pathway foldchange, the significant pathway results and a diagnostic scatter plot
               mainPanel(
                 tabsetPanel(
                   tabPanel("Barplot NES",
                            plotOutput("barplot_fgsea", click = "bar_click")),
                   tabPanel("Results Table",
                            DTOutput("fgsea_table")),
                   tabPanel("Scatter Plot",
                            plotOutput("scatter_fgsea"))
                 )
               )))
  )
)

# Define server logic required
server <- function(input, output, session) {
  options(shiny.maxRequestSize=30*1024^2)

  ### Samples Tab ###
  # The following is the server side for tab 1: Samples  
  # we always use reactive expressions
  load_data_t1 <- reactive({
    req(input$Tab1Input)
    tryCatch({
      # here we read the input csv
      datat1 <- read_csv(input$Tab1Input$datapath, show_col_types = FALSE) %>%
        rename_with(~ make.names(.)) %>%
        as_tibble()
      print("Loaded data column names:")
      print(colnames(datat1))
      return(datat1)
    }, error = function(e) {
      showNotification("Error reading file. Ensure it is valid CSV with clean headers.", type = "error")
      stop("Error in load_data_t1: ", e$message)
    })
  })

  # make the metadata table
  generate_metadata <- function(data) {
    # Ensure data is a tibble
    data <- as_tibble(data)
    
    print("Columns being summarized:")
    print(colnames(data))
    
    # Generate metadata by determining the value type in each column
    # gather mean and stdev for the continuous variables
    # and the options for distinct values
    metadata <- data.frame(
      `Column Name` = colnames(data),
      Type = sapply(data, function(x) {
        if (is.numeric(x)) return("double")
        if (is.character(x) || is.factor(x)) return("factor/character")
        return("other")
      }),
      `Mean (sd) or Distinct Values` = sapply(data, function(x) {
        if (is.numeric(x)) {
          return(paste0(round(mean(x, na.rm = TRUE), 2), " (+/- ", round(sd(x, na.rm = TRUE), 2), ")"))
        } else if (is.character(x) || is.factor(x)) {
          return(paste(unique(x), collapse = ", "))
        }
        return("Unsupported column type")
      })
    )
    
    return(metadata)
  }
  
  # the metadata table is a simple print of the entered table
  output$metadata <- renderTable({
    datat1 <- load_data_t1()
    req(datat1)
    metadata <- generate_metadata(datat1)
    metadata
  })
  
  output$sampletable = DT::renderDataTable({
    as.data.frame(load_data_t1())
  })
  # now we can make a table that specifies the numeric and character columns
  observe({
    req(load_data_t1())
    continuous_vars <- load_data_t1() %>% dplyr::select(where(is.numeric)) %>% colnames()
    categorical_vars <- load_data_t1() %>% dplyr::select(where(is.character) | where(is.factor)) %>% colnames()
    
    updateSelectInput(session, "ridge_var", choices = continuous_vars, selected = continuous_vars[1])
    updateSelectInput(session, "ridge_group", choices = categorical_vars, selected = categorical_vars[1])
  })
  
  # Generate summary table text
  output$table_summary <- renderText({
    req(metadata())
    paste("Number of rows:", nrow(metadata()), " | Number of columns:", ncol(metadata()))
  })
  
  # Sortable data table
  output$sortable_table <- renderDT({
    req(metadata())
    datatable(metadata(), options = list(pageLength = 10))
  })
  
  # Ridgeline plot, we apply the user selected continuous variable and the group
  output$ridgeline_plot <- renderPlot({
    req(load_data_t1(), input$ridge_var, input$ridge_group)
    
    ggplot(load_data_t1(), aes_string(x = input$ridge_var, y = input$ridge_group, fill = input$ridge_group)) +
      geom_density_ridges(scale = ifelse(input$scale_density, 1.2, 1)) +
      scale_fill_brewer(palette = "Set2") +
      labs(
        title = "Ridgeline Plot",
        x = input$ridge_var,
        y = input$ridge_group
      ) +
      theme_ridges() +
      theme(legend.position = "none")
  })
  
  
  
  load_data <- reactive({
    req(input$Input)
    # if the entered file is null, we return null
    tryCatch({
      data <- read.csv(file = input$Input$datapath, header = TRUE)
      print(head(data))
      return(data)
    }, error = function(e) {
      showNotification("Error reading file. Ensure it is valid CSV", type = "error")
      return(NULL)
    })
  })
  
  #### Counts Tab ####
  # store the entered counts in a variable
  counts_data <- reactive ({
    req(input$counts)
    
    df <- read_tsv(input$counts$datapath)
    # create a table evaluating the counts matrix for zeros and the variance
    df_filtered <- df %>%
      rowwise() %>%
      mutate(MedianCount = median(c_across(-1)),
             Variance = var(c_across(-1)),
             Nonzero = sum(c_across(-1) > 0),
             NumZeros = ncol(df) - 1 - Nonzero
      ) %>%
      ungroup()
    # take user input of the variance threshold
    variance_threshold <- quantile(df_filtered$Variance, input$var_threshold / 100)
    # pass the filter
    df_filtered <- df_filtered %>%
      mutate(PassFilter = Variance >= variance_threshold & Nonzero >= input$zero_threshold)
    # return the filtered data table
    return(df_filtered)
  })
  # create a summary of the counts matrix
  # while also considering the user input
  output$countssummary <- renderTable({
    req(counts_data())
    df <- counts_data()
    
    total_genes <- nrow(df)
    passing_genes <- sum(df$PassFilter)
    failing_genes <- total_genes - passing_genes
    
    summary <- tibble(
      "Total Samples" = ncol(df) - 3,
      "Total Genes" = total_genes,
      "Genes Passing Filter" = passing_genes,
      "Percetange Passing" = round((passing_genes / total_genes) * 100, 2),
      "Genes Failing Filter" = failing_genes,
      "Percentage Failing" = round((failing_genes / total_genes) * 100, 2)
    )
    
    summary
  })
  # the scatter diagnostic plot will help us evauluate the quality of the counts matrix
  # the user has the option to look at the variance or the zero counts
  # first the variance
  output$scatter_plot <- renderPlot({
    req(counts_data())
    df <- counts_data()
    
    if (input$plot_type == "variance") {
      ggplot(df, aes(x = MedianCount, y = Variance, color = PassFilter)) +
        geom_point(alpha = 0.6) +
        scale_x_log10() +
        scale_y_log10() +
        scale_color_manual(values = c("TRUE" = "darkblue", "FALSE" = "lightgrey")) +
        labs(
          title = "Median Count vs Variance",
          x = "Median Count (log scale)",
          y = "Variance (log scale)",
          color = "Pass Filter"
        ) +
        theme_minimal()
      # and the zero counts
    } else if (input$plot_type == "zeros") {
      ggplot(df, aes(x = MedianCount, y = NumZeros, color = PassFilter)) +
        geom_point(alpha = 0.6) +
        scale_x_log10() +
        scale_color_manual(values = c("TRUE" = "darkgreen", "FALSE" = "lightgrey")) +
        labs (
          title = "Median Count vs Number of Zeros",
          x = "Median Count (log scales)",
          y = "Number of Zeros",
          color = "Pass Filter"
        ) +
        theme_minimal()
    }
  })
  # now we create a heatmap for the counts martix
  # the only user input here is whether the heatmap should be displayed log scale or not
  output$heatmap_plot <- renderPlot({
    req(counts_data())
    df <- counts_data() %>% filter(PassFilter) %>% dplyr::select(-MedianCount, -Variance, -Nonzero, -NumZeros, -PassFilter)
    
    mat <- as.matrix(df[, -1])
    rownames(mat) <- df[[1]]
    
    if (input$log_transform) mat <- log2(mat + 1)
    
    Heatmap(
      mat,
      name = "Expression",
      show_row_names = FALSE,
      cluster_columns = TRUE,
      cluster_rows = TRUE,
      col = colorRamp2(c(min(mat), max(mat)), c("blue", "red"))
    )
  })

  # finally, we create a PCA plot to better understand our samples
  # each point on the PCA plot represents a different sample
  # we expect the control and the experimental groups to cluster together
  output$pca_plot <- renderPlot({
    req(counts_data())
    df <- counts_data() %>% filter(PassFilter) %>% dplyr::select(-MedianCount, -Variance, -Nonzero, -NumZeros, -PassFilter)
    
    mat <- as.matrix(df[, -1])
    rownames(mat) <- df[[1]]  
    mat <- na.omit(mat)       
    rownames(mat) <- df[[1]]
    
    pca <- prcomp(t(mat), scale. = TRUE)
    pcs <- as_tibble(pca$x)
    explained <- round(100 * pca$sdev^2 / sum(pca$sdev^2), 1)
    # here we create the scatter plot
    ggplot(pcs, aes_string(x = input$pc_x, y = input$pc_y)) +
      geom_point(color = "darkorange") +
      labs(
        title = "PCA Scatter Plot",
        x = paste0(input$pc_x, " (", explained[as.numeric(substr(input$pc_x, 3, 3))], "% Variance Explained)"),
        y = paste0(input$pc_y, " (", explained[as.numeric(substr(input$pc_y, 3, 3))], "% Variance Explained)")
      ) +
      theme_minimal()
  })
  
  #### Volcano plot
  volcano_plot <- function(dataf, x_name, y_name, slider, color1, color2) {
    # in order to plot, we have to change the formatting of the selected x and y axes
    x_sym <- rlang::sym(x_name)
    y_sym <- rlang::sym(y_name)
    # create a plot using ggplot2, formatting is key here we need to use !! to perform numerical functions
    plot <- ggplot(dataf, aes(x = !!x_sym, y = -log10(!!y_sym))) +
      # and we plot the points in different colors based on certain values
      geom_point(aes(color = ifelse(!!y_sym <= 10^slider, color2, color1))) +
      # this helps ggplot define the colors
      scale_color_identity() +
      # and finally we add axis labels
      labs(x = x_name, y = paste("-log10(", y_name, ")", sep = ""))
    return(plot)
  }
  
  # run if the action button is pressed
  observeEvent(input$button, {
    runif(input$Input)
  })
  
  output$volcano <- renderPlot({
    # the data must be loaded first
    req(load_data())
    # create a variable for it
    data <- load_data()
    # and put the data and user inputs through the volcano plot function
    volcano_plot(data, input$choices1, input$choices2, input$threshold, input$color1, input$color2)
  })
  
  # create filtered data (i.e. user input threshold levels)
  filtered_data <- reactive({
    req(load_data())
    # store data in a variable
    data <- load_data()
    
    # create a variable for the threshold input
    threshold_val <- 10^input$threshold
    # apply it to the padj column of the data
    data_filtered <- subset(data, padj <= threshold_val)
    # format the filtered data to account for the first 5 digits in pvalue and padj
    data_filtered$pvalue <- formatC(data_filtered$pvalue, format = "e", digits = 5)
    data_filtered$padj <- formatC(data_filtered$padj, format = "e", digits = 5)
    # finally, return the filtered data
    return(data_filtered)
  })
  
  output$table <- renderTable({
    req(filtered_data())
    data <- filtered_data()
    data
    # but we only want to show the top 20
    head(data, n = 20)
  },
  # this formats the table
  striped = TRUE,
  hover = TRUE,
  bordered = TRUE
  )
  ### GSEA TAB###
  # we ask for user input for the deseq results and the gmt pathways
  deseq_data <- reactive({
    req(input$deseq_file)
    read_csv(input$deseq_file$datapath)
  })
  
  gene_sets <- reactive({
    req(input$gmt_file)
    gmtPathways(input$gmt_file$datapath)
  })
  
  # Load Gene Sets
  ranked_genes <- reactive({
    req(deseq_data())
    data <- deseq_data()
    
    # Move rownames to a SYMBOL column if necessary
    if (is.null(rownames(data))) stop("Rownames are missing. Ensure input file is properly formatted.")
    
    data <- data %>%
      rownames_to_column(var = "SYMBOL") %>%
      as_tibble()
    
    # Process ranks
    ranks <- data %>%
      drop_na(stat) %>%
      distinct(SYMBOL, stat) %>%
      group_by(SYMBOL) %>%
      summarize(stat = mean(stat)) %>%
      deframe()
    
    return(ranks)
  })
  
  # Run FGSEA
  fgsea_results <- reactive({
    req(ranked_genes(), gene_sets())
    fgsea(pathways = gene_sets(), stats = ranked_genes(), nperm = 1000) %>%
      arrange(padj) %>%
      as_tibble()
  })
  
  ### GSEA BARPLOT ###
  output$barplot_fgsea <- renderPlot({
    req(fgsea_results())
    top_n <- input$top_pathways
    fgsea_top <- fgsea_results() %>% head(top_n)
    
    ggplot(fgsea_top, aes(x = reorder(pathway, NES), y = NES, fill = padj < 0.05)) +
      geom_col() +
      coord_flip() +
      scale_fill_manual(values = c("TRUE" = "red", "FALSE" = "grey")) +
      labs(title = "Top Enriched Pathways", x = "Pathway", y = "Normalized Enrichment Score (NES)") +
      theme_minimal()
  })
  
  ### RESULTS TABLE ###
  output$fgsea_table <- renderDT({
    req(fgsea_results())
    fgsea_results() %>%
      filter(padj <= input$padj_filter) %>%
      {if (input$nes_direction == "pos") filter(., NES > 0) else if (input$nes_direction == "neg") filter(., NES < 0) else .}
  })
  
  ### SCATTER PLOT ###
  # user input is implemented into the thresholds and coloring of the plt
  output$scatter_fgsea <- renderPlot({
    req(fgsea_results())
    threshold <- input$padj_filtered_scatter
    
    ggplot(fgsea_results(), aes(x = NES, y = -log10(padj), color = padj <= threshold)) +
      geom_point(alpha = 0.6) +
      scale_color_manual(values = c("TRUE" = "red", "FALSE" = "grey")) +
      labs(title = "Scatter Plot of NES vs -log10(padj)",
           x = "Normalized Enrichment Score (NES)",
           y = "-log10 Adjusted P-Value",
           color = "Significant") +
      theme_minimal()
  })
  
}
# Run the application
shinyApp(ui = ui, server = server)
