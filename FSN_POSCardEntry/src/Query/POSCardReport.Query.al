query 50010 "FSN POS Card Report"
{
    // WVILLALLTA04OCT19             - New

    OrderBy = Ascending(Transaction_Status), Ascending(Date);

    elements
    {
        dataitem(Trans_Payment_Entry; "LSC Trans. Payment Entry")
        {
            column(Transaction_Status; "Transaction Status")
            {
            }
            column(Date; Date)
            {
            }
            column(Store_No; "Store No.")
            {
            }
            column(POS_Terminal_No; "POS Terminal No.")
            {
            }
            column(Transaction_No; "Transaction No.")
            {
            }
            dataitem(POS_Card_Entry; "LSC POS Card Entry")
            {
                DataItemLink = "Store No." = Trans_Payment_Entry."Store No.",
                                "POS Terminal No." = Trans_Payment_Entry."POS Terminal No.",
                                "Transaction No." = Trans_Payment_Entry."Transaction No.",
                                "Line No." = Trans_Payment_Entry."Line No.";
                SqlJoinType = InnerJoin;
                column(Transaction_Type; "Transaction Type")
                {
                }
                column(MSR_input; "MSR input")
                {
                }
                column(Tender_Type; "Tender Type")
                {
                }
                column(Date_CardEntry; Date)
                {
                }
                column(Time; Time)
                {
                }
                column(Authorisation_Ok; "Authorisation Ok")
                {
                }
                column(Auth_code; "Auth.code")
                {
                }
                column(EFT_Batch_No; "EFT Batch No.")
                {
                }
                column(Amount; Amount)
                {
                }
                column(Nombre_Tarjeta; "FSN Bank Name")
                {
                }
                column(Nombre_Operador; "FSN Operation Name")
                {
                }
                column(Ultimos_Digitos; "FSN Last Digits")
                {
                }
                column(BIN_No; "FSN BIN No.")
                {
                }
            }
        }
    }
}

