query 50002 "FSN Transfer Consistency"
{
    // WVILLALTA02ABR19                - Recovery consistency (Delete Transfer)
    elements
    {
        dataitem(QueryElement2; "Transfer Header")
        {
            dataitem(QueryElement1; PITS_WMScd2suc)
            {
                DataItemLink = "Source No." = QueryElement2."No.";
                SqlJoinType = InnerJoin;
                DataItemTableFilter = Completado = CONST(true);
                column(Source_No; "Source No.")
                {
                }
                column(Completado; Completado)
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

