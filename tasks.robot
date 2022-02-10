*** Settings ***
Documentation     Orders robots from RobotSpareBin Industries Inc.
...               Saves the order HTML receipt as a PDF file.
...               Saves the screenshot of the ordered robot.
...               Embeds the screenshot of the robot to the PDF receipt.
...               Creates ZIP archive of the receipts and the images.
Library           RPA.Browser.Selenium    auto_close=${FALSE}
Library           RPA.HTTP
Library           RPA.Tables
#Library          RPA.JavaAccessBridge
Library           RPA.PDF
Library           XML
Library           RPA.Archive
Library           RPA.Robocorp.Vault

*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Open the robot order website
    ${orders}=    Get orders
    #${for_loop_once}=    Set Variable    1
    FOR    ${row}    IN    @{orders}
        #Exit For Loop If    ${for_loop_once} > 5
        Close the annoying modal
        Fill the form    ${row}
        Preview the robot
        ${order_submit_retry_counter}=    Set Variable    0
        Submit the order    ${order_submit_retry_counter}
        ${pdf}=    Store the receipt as a PDF file    ${row}[Order number]
        ${screenshot}=    Take a screenshot of the robot    ${row}[Order number]
        Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}
        Go to order another robot
        #${for_loop_once}=    Evaluate    ${for_loop_once} + 1
    END
    Create a ZIP file of the receipts
    [Teardown]    Close the browser and go home

*** Keywords ***
Open the robot order website
    ${secret_url}=    Get Secret    web_paths
    Open Available Browser    ${secret_url}[purchase_url]

Get Orders
    Download    https://robotsparebinindustries.com/orders.csv    overwrite=true
    ${order_table}=    Read table from CSV    orders.csv
    [Return]    ${order_table}

Close the annoying modal
    Wait Until Element Is Visible    css:.modal-header
    Click Button    css:.btn:nth-child(3)

Fill the form
    [Arguments]    ${row}
    Select From List By Index    id:head    ${row}[Head]
    Select Radio Button    body    id-body-${row}[Body]
    Input Text    css:.form-control    ${row}[Legs]
    Input Text    id:address    ${row}[Address]

Preview the robot
    Click Button    id:preview
    Wait Until Element Is Visible    id:robot-preview-image

Submit the order
    [Arguments]    ${retry_counter}
    Click Button    id:order
    # Check if "alert-danger" class exists (failed submission)
    ${is_alert}=    Run Keyword And Return Status    RPA.Browser.Selenium.Get Element Attribute    css:.alert-danger    innerHTML
    IF    ${isalert} == True    # If failed submission, try submitting again:
        IF    ${retry_counter} == 6
            Log    Giving up after 5 consecutive failed submissions on one order, bot process exiting...
            Close the browser and go home
        END
        ${retry_counter}=    Evaluate    ${retry_counter} + 1    # Increment retry counter
        Submit the order    ${retry_counter}    # Call keyword to submit order again
    END

Store the receipt as a PDF file
    [Arguments]    ${current_order_number}
    ${receipt_html}=    RPA.Browser.Selenium.Get Element Attribute    id:receipt    outerHTML
    Html to Pdf    ${receipt_html}    ${OUTPUT_DIR}${/}pdf_folder${/}receipt_order_num_${current_order_number}.pdf
    [Return]    ${OUTPUT_DIR}${/}pdf_folder${/}receipt_order_num_${current_order_number}.pdf

Take a screenshot of the robot
    [Arguments]    ${current_order_number}
    Wait Until Element Is Visible    id:robot-preview-image
    Screenshot    id:robot-preview-image    ${OUTPUT_DIR}${/}order_preview_${current_order_number}.png
    [Return]    ${OUTPUT_DIR}${/}order_preview_${current_order_number}.png

Embed the robot screenshot to the receipt PDF file
# Args received:
#    screenshot: full path + file name + extension to image file
#    pdf:    full path + file name + extension to pdf file
    [Arguments]    ${screenshot}    ${pdf}
    Open Pdf    ${pdf}
    ${image_src}=    Create List    ${screenshot}    # Create a list with one element
    Add Files To Pdf    ${image_src}    ${pdf}    append=True
    Close Pdf    ${pdf}

Create a ZIP file of the receipts
    ${zip_file_name}=    Set Variable    ${OUTPUT_DIR}/PDFs.zip
    Log    ${CURDIR}
    Log    ${OUTPUT_DIR}
    Archive Folder With Zip    ${OUTPUT_DIR}${/}pdf_folder    ${zip_file_name}

Go to order another robot
    Click Button    id:order-another

Close the browser and go home
    Close Browser
