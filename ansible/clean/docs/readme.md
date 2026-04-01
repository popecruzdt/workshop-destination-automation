# Clean Function

This function removes resources created by the deploy function.

## Playbooks

- `clean/playbooks/remove_app.yml`: removes easyTravel containers and network
- `clean/playbooks/remove_image.yml`: removes the built easyTravel image
- `clean/playbooks/site.yml`: runs `remove_app` and then `remove_image`

## Notes

- App and image cleanup are intentionally separated.
- Volume cleanup is optional and controlled by `podman_clean_remove_volumes`.
