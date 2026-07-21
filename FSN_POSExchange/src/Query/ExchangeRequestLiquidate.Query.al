query 50004 "FSN Exchange Request Liquidate"
{

    elements
    {
        dataitem(QueryElement1; "FSN POS Exchange Transaction")
        {
            DataItemTableFilter = Status = CONST("Request Liquidate CN");
            column(Status; Status)
            {
            }
            column(External_Document_No; "External Document No.")
            {
            }
            column(Max_Amount_Doc_Inc_VAT; "Amount Doc. Inc. VAT")
            {
                Method = Max;
            }
            column(Count_)
            {
                Method = Count;
            }
        }
    }
}

