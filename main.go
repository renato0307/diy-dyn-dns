package main

import (
	"log"
	"net/http"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/route53"
	"github.com/aws/aws-sdk-go/service/ssm"
)

var apiKeyValue *string

// Handler is your Lambda function handler
// It uses Amazon API Gateway request/responses provided by the aws-lambda-go/events package,
// However you could use other event sources (S3, Kinesis etc), or JSON-decoded primitive types such as 'string'.
func Handler(request events.LambdaFunctionURLRequest) (events.LambdaFunctionURLResponse, error) {

	log.Printf("http method %v", request.RequestContext.HTTP.Method)

	httpResponse, err := handleAuthz(request)
	if httpResponse != nil || err != nil {
		return *httpResponse, err
	}

	httpResponse, err = createOrUpdateDNSRecord(request)
	if httpResponse != nil || err != nil {
		return *httpResponse, err
	}

	return events.LambdaFunctionURLResponse{
		Body:       "Hello world",
		StatusCode: 200,
	}, nil
}

func handleAuthz(request events.LambdaFunctionURLRequest) (*events.LambdaFunctionURLResponse, error) {
	if apiKeyValue == nil {
		for h := range request.Headers {
			log.Printf("header %s found", h)
		}
		sess, err := session.NewSession(&aws.Config{})
		if err != nil {
			log.Printf("error starting AWS session: %s", err)
			return &events.LambdaFunctionURLResponse{
				StatusCode: http.StatusInternalServerError,
			}, nil
		}
		svc := ssm.New(sess)

		apiKeyParamName := os.Getenv("API_KEY_PARAM_NAME")
		apiKey, err := svc.GetParameter(&ssm.GetParameterInput{Name: &apiKeyParamName, WithDecryption: aws.Bool(true)})
		if err != nil {
			log.Printf("error reading API key: %s", err)
			return &events.LambdaFunctionURLResponse{
				StatusCode: http.StatusInternalServerError,
			}, nil
		}
		apiKeyValue = apiKey.Parameter.Value
	}

	authHeader := request.Headers["authorization"]
	log.Printf("validating the API key... %d %d", len(*apiKeyValue), len(authHeader))
	if *apiKeyValue != authHeader {
		log.Printf("not authorized")
		return &events.LambdaFunctionURLResponse{
			StatusCode: http.StatusForbidden,
		}, nil
	}
	log.Printf("auth ok!")
	return nil, nil
}

func createOrUpdateDNSRecord(request events.LambdaFunctionURLRequest) (*events.LambdaFunctionURLResponse, error) {
	dnsHostedZone := os.Getenv("DNS_HOSTED_ZONE")
	dnsDynRecordName := os.Getenv("DNS_DYN_RECORD_NAME")

	sess, err := session.NewSession(&aws.Config{})
	if err != nil {
		log.Printf("error starting AWS session: %s", err)
		return &events.LambdaFunctionURLResponse{
			StatusCode: http.StatusInternalServerError,
		}, nil
	}
	svc := route53.New(sess)

	_, err = svc.ChangeResourceRecordSets(
		&route53.ChangeResourceRecordSetsInput{
			HostedZoneId: aws.String(dnsHostedZone),
			ChangeBatch: &route53.ChangeBatch{
				Changes: []*route53.Change{
					{
						Action: aws.String("UPSERT"),
						ResourceRecordSet: &route53.ResourceRecordSet{
							Name: &dnsDynRecordName,
							TTL:  aws.Int64(300),
							Type: aws.String("A"),
							ResourceRecords: []*route53.ResourceRecord{
								{
									Value: aws.String(request.RequestContext.HTTP.SourceIP),
								},
							},
						},
					},
				},
			},
		},
	)
	if err != nil {
		log.Printf("error creating the route53 record: %s", err)
		return &events.LambdaFunctionURLResponse{
			StatusCode: http.StatusInternalServerError,
		}, nil
	}

	return nil, nil
}

func main() {
	log.Printf("starting lambda")
	lambda.Start(Handler)
}
