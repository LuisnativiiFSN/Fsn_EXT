query 50003 "FSN External Transfer Invoice"
{
    // WVILLALTA02ABR19                - GET Transfer Invoice External data
    elements
    {
        dataitem(QueryElement1; PITS_WMScd2suc)
        {
            DataItemTableFilter = "No. Remision" = FILTER(<> '');
            column(SourceNo; "Source No.")
            {
            }
            column(Remision; "No. Remision")
            {
            }
            column(Starting_Date; "Starting Date")
            {
            }
            column(Shipment; "No.")
            {
            }
            column(Completado; Completado)
            {
            }
            column(TransferCompleto; TransferComplete)
            {
            }
            column(Shipped; Shipped)
            {
            }
            column(Sum_Quantity; Quantity)
            {
                Method = Sum;
            }
            dataitem(QueryElement9; "Transfer Header")
            {
                DataItemLink = "No." = QueryElement1."Source No.";
                SqlJoinType = InnerJoin;
                column(No; "No.")
                {
                }
                column(Transfer_to_Code; "Transfer-to Code")
                {

                }
            }

        }
    }
}

