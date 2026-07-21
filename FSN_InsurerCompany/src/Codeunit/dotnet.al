dotnet
{
    assembly("System.Xml")
    {
        Version = '2.0.0.0';
        Culture = 'neutral';
        PublicKeyToken = 'b77a5c561934e089';

        type("System.Xml.XmlDocument"; "DocumentXml")
        {
        }

        type("System.Xml.XmlNode"; "NodeXml")
        {
        }

        type("System.Xml.XmlNodeList"; "NodeListXml")
        {
        }
    }

    assembly("System.Data")
    {
        Version = '4.0.0.0';
        Culture = 'neutral';
        PublicKeyToken = 'b77a5c561934e089';

        type("System.Data.SqlClient.SqlConnection"; "SqlConnection")
        {
        }

        type("System.Data.SqlClient.SqlCommand"; "SqlCommand")
        {
        }

        type("System.Data.SqlClient.SqlDataReader"; "SqlDataReader")
        {
        }
    }
}
