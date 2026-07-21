page 50137 "FSN Recep. Purch. DTE"
{
    Caption = 'FSN Recep. Purch. DTE';
    DataCaptionFields = "VAT Registration No.";
    Editable = false;
    PageType = List;
    SourceTable = "FSN Recep. Purch. DTE";

    layout
    {
        area(content)
        {
            repeater(Control1)
            {
                field("No."; "No.")
                {

                }
                field("VAT Registration No."; "VAT Registration No.")
                {

                }
                field("DTE AuthNumber"; "DTE AuthNumber")
                {

                }
                field("DTE Invoice"; "DTE Invoice")
                {

                }
                field("Signature Validation"; "Signature Validation")
                {

                }
                field("Issue Date"; "Issue Date")
                {

                }
                field("Entry Date"; "Entry Date")
                {

                }
            }
        }
    }
}