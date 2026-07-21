query 50001 "FSN External Purc. Consistency"
{

    elements
    {
        dataitem(QueryElement1; "Purchase Header")
        {
            column(No; "No.")
            {
            }
            column(Buy_from_Vendor_No; "Buy-from Vendor No.")
            {
            }
            dataitem(QueryElement4; "FSN External Purch. Sub Line")
            {
                DataItemLink = "No." = QueryElement1."No.";
                SqlJoinType = InnerJoin;
                column(SubLineNo; "No.")
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
}

