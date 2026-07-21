query 50006 "FSN Get Purchase per Vendor"
{
    QueryType = Normal;

    elements
    {
        dataitem(Purchases; "Purchase Header")
        {
            column(Vendor_Order_No_; "Vendor Order No.")
            {
            }
            column(Order_Date; "Order Date")
            {
            }
            column(FSN_Consolidate_No_; "FSN Consolidate No.")
            {

            }
            column(Invoice_Discount_Value; "Invoice Discount Value")
            {

                Method = Sum;
            }
            /*filter(FilterName; SourceFieldName)
            {
            }*/
        }
    }
    trigger OnBeforeOpen()
    begin

    end;
}