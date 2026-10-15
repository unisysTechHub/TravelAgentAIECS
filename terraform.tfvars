aws_region = "ap-south-2"

frontend_image = "637452052867.dkr.ecr.ap-south-2.amazonaws.com/unisystechhub/frontend"

microservice_images = {
  TravelAgentService      = "637452052867.dkr.ecr.ap-south-2.amazonaws.com/unisystechhub/travel-agent-ai:latest"
  FlightMCPService        = "637452052867.dkr.ecr.ap-south-2.amazonaws.com/unisystech/flightmcp-server:latest"
  HotelMCPService = "637452052867.dkr.ecr.ap-south-2.amazonaws.com/unisystechhub/hotel-mp-service:latest"
}