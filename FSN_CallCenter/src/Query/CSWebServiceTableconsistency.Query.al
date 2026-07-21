query 50008 "FSN CSWebServiceTable Status"
{

    elements
    {
        dataitem(QueryElement1; "FSN WebServiceTable")
        {
            DataItemTableFilter = "Status WS" = CONST(InProcess);
            column(LastSlipNo; LastSlipNo)
            {
            }
            column(Status_WS; "Status WS")
            {
            }
            column(Date; Date)
            {
            }
            dataitem(QueryElement4; "LSC POS Transaction")
            {
                DataItemLink = "Receipt No." = QueryElement1.LastSlipNo;
                SqlJoinType = InnerJoin;
                column(Entry_Status; "Entry Status")
                {
                }
                column(Receipt_No; "Receipt No.")
                {
                }
                dataitem(QueryElement7; "LSC Delivery Order")
                {
                    DataItemLink = "Order No." = QueryElement1.LastSlipNo;
                    SqlJoinType = LeftOuterJoin;
                    column(Order_No; "Order No.")
                    {
                    }
                }
            }
        }
    }
}

