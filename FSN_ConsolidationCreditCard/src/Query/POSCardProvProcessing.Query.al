query 50009 "FSN POS Card Prov. Processing"
{
    // WVILLALTA 9.20                    -  Control card payment


    elements
    {
        dataitem(POS_Card_Prov_VS_Customer; "FSN POS Card Prov. VS Customer")
        {
            DataItemTableFilter = Status = FILTER(<> MatchReverse);
            dataitem(TransactionHeader; "LSC Transaction Header")
            {
                DataItemLink = "Store No." = POS_Card_Prov_VS_Customer."Store No.",//"POS_Card_Prov_VS_Customer.Store No.",
                "POS Terminal No." = POS_Card_Prov_VS_Customer."POS Terminal No.",
                "Transaction No." = POS_Card_Prov_VS_Customer."Transaction No.";
                SqlJoinType = InnerJoin;
                DataItemTableFilter = "Sale Is Return Sale" = CONST(true),
                "Entry Status" = CONST(" ");
                column(Store_No; "Store No.")
                {
                }
                column(POS_Terminal_No; "POS Terminal No.")
                {
                }
                column(Transaction_No; "Transaction No.")
                {
                }
                column(Retrieved_from_Receipt_No; "Retrieved from Receipt No.")
                {
                }
                column(Sum_Payment; Payment)
                {
                    Method = Sum;
                }
            }
        }
    }
}

