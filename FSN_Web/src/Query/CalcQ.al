
query 50007 "Periodic Discount"
{
    QueryType = Normal;

    elements
    {
        dataitem(periodicDiscount; "LSC Periodic Discount")
        {
            DataItemTableFilter = Status = filter(= 1);
            column(OfferNo; "No.")
            {

            }
            column(Priority; Priority)
            {

            }
            dataitem(periodicDiscountLine; "LSC Periodic Discount Line")
            {
                DataItemLink = "Offer No." = periodicDiscount."No.";
                SqlJoinType = InnerJoin;

                column(No; "No.")
                {

                }
                column(Description; "Description")
                {

                }
                column(Standard_Price_Including_VAT; "Standard Price Including VAT")
                {

                }
                column(Offer_Price_Including_VAT; "Offer Price Including VAT")
                {

                }
                column(LineNo; "Line No.")
                {

                }
            }

        }
    }
}