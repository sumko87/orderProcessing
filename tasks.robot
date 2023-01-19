*** Settings ***
Documentation       Robot for processing orders.

Library             RPA.HTTP
Library             RPA.Browser.Selenium    #auto_close=${FALSE}
Library             RPA.Tables
Library             RPA.PDF
Library             RPA.Archive
Library             RPA.FileSystem
Library             Collections
Library             RPA.Robocorp.Vault
Library             RPA.Dialogs


*** Tasks ***
Minimal task
    read settings from local vault
    input dialog
    Log    ${NAME}
    download input file and read as table
    process orders
    Zip and show results


*** Keywords ***
read settings from local vault
    ${secret}    Get Secret    robotSpareBin
    Set Global Variable    ${SETTINGS}    ${secret}

input dialog
    add image    ${SETTINGS}[dancingRobotGIF]    height=200
    add heading    hello there!
    add text    i am here to help you process orders on robotsparebin
    Add text input    name=name    label=Name    placeholder=please type your name
    TRY
        ${result}    Run dialog    timeout=60    title=Order Processing    height=640    width=480
        Set Global Variable    ${NAME}    ${result.name}
    EXCEPT
        Log    autoclosed input dialog
        Set Global Variable    ${NAME}    noName
    END

download input file and read as table
    Download
    ...    url=${SETTINGS}[inputFileURL]
    ...    target_file=${SETTINGS}[inputFileName]
    ...    overwrite=true
    ...    verify=false
    ${dt_orders}    Read table from CSV    ${SETTINGS}[inputFileName]
    Set Global Variable    ${DT_ORDERS}    ${dt_orders}    #making orders dt variable available globaly

process orders
    Open Available Browser    url=${SETTINGS}[orderProcessingURL]
    Maximize Browser Window
    FOR    ${row}    IN    @{DT_ORDERS}
        Click Button    OK
        Log    orderNUmber: ${row}[Order number]
        Select From List By Value    css:#head    ${row}[Head]
        Select Radio Button    body    ${row}[Body]
        Log    Legs: ${row}[Legs]
        Input Text    css:form div.form-group:nth-child(3) input    ${row}[Legs]
        Input Text    css:#address    ${row}[Address]
        Click Button    css:button#preview
        Screenshot    css:div#robot-preview-image    ${OUTPUT_DIR}/images/${row}[Order number].png
        Click Button    css:button#order
        ${order_successfull}    Set Variable    ${False}

        #Wait Until Keyword Succeeds    3x    0.5 sec    Your keyword that you want to retry
        WHILE    ${order_successfull} == ${False}
            TRY
                ${receipt}    Get Element Attribute    css:div#receipt    outerHTML
                log    ${receipt}
                Html To Pdf    ${receipt}    ${OUTPUT_DIR}/receiptsData/${row}[Order number].pdf
                Click Button    css:button#order-another
                ${order_successfull}    Set Variable    ${True}
            EXCEPT
                Click Button    css:button#order
                ${order_successfull}    Set Variable    ${False}
            END
        END
        Open Pdf    ${OUTPUT_DIR}/receiptsData/${row}[Order number].pdf
        ${files}    Create List
        ...    ${OUTPUT_DIR}/receiptsData/${row}[Order number].pdf
        ...    ${OUTPUT_DIR}/images/${row}[Order number].png
        Add Files To Pdf    ${files}    ${OUTPUT_DIR}/${row}[Order number].pdf
        Close Pdf
    END

Zip and show results
    Archive Folder With Zip    ${OUTPUT_DIR}    ${OUTPUT_DIR}/receipts.zip    include=*.pdf
    add heading    All orders are processed ${NAME}!
    Add icon    success
    Add text    here are the receipts:
    Add file    ${OUTPUT_DIR}/receipts.zip    receipts.zip
    TRY
        ${result}    Run dialog    timeout=60    title=result    height=640    width=480
    EXCEPT
        Log    autoclosed result dialog
    END
