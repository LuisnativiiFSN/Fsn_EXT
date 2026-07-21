query 50000 "FSN External Document Invoice"
{
    // WVILLALTA13DIC18      - Modificado completamente Antes era tabla 50017 pasa a 50019


    elements
    {
        dataitem(QueryElement4; "FSN External Purch. Sub Line")
        {
            DataItemTableFilter = "Status Sub. Line" = FILTER(New | ErrorValidation | CloseErasePurch | Canceled);
            column(No_; "No.")
            {
            }
            column(External_Document_No; "External Document No.")
            {
            }
            column(Status_Sub_Line; "Status Sub. Line")
            {
            }
            column(Sum_Qty_to_Ship; "Qty. to Ship")
            {
                Method = Sum;
            }
        }
    }
}

